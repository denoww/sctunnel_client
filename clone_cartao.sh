#!/bin/bash
# clone_cartao.sh — clona um pendrive/SD do Orange Pi 3 LTS pra outro pendrive,
# preservando bootabilidade (U-Boot SPL no offset 8 KiB + UUID idêntica do rootfs).
#
# Uso:
#   bash clone_cartao.sh                          # auto-detecta fonte e destino
#   bash clone_cartao.sh --src /dev/sdX           # destino auto, fonte explícita
#   bash clone_cartao.sh --src /dev/sdX --dst /dev/sdY
#   bash clone_cartao.sh --img ~/orangepi.img     # também exporta .img no final
#   bash clone_cartao.sh --yes                    # pula confirmações (uso em CI)
#
# Fonte = pendrive USB com U-Boot SPL (magic eGON.BT0 no sector 16).
# Destino = outro pendrive USB com >= 4 GB de capacidade real.
# Estratégia: rebuild fresco no destino. Fonte é montada READ-ONLY, NUNCA escrita.
set -euo pipefail

# ===== Layout idêntico à eMMC do Orange Pi 3 LTS (max portabilidade) =====
PART_START=8192
PART_END=15106047
PART_SECTORS=$(( PART_END - PART_START + 1 ))   # 15097856 sectors = 7.2 GB
EGON_HEX="65474f4e2e425430"   # "eGON.BT0" em hex

SRC=""
DST=""
IMG=""
ASSUME_YES=0

# ===== Argparse =====
while [ $# -gt 0 ]; do
  case "$1" in
    --src) SRC=$2; shift 2 ;;
    --dst) DST=$2; shift 2 ;;
    --img) IMG=$2; shift 2 ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Argumento desconhecido: $1"; exit 1 ;;
  esac
done

# ===== Helpers =====
has_egon() {
  # $1 = block device. Lê sector 16 e checa magic eGON.BT0.
  sudo dd if="$1" bs=512 skip=16 count=1 status=none 2>/dev/null \
    | xxd -p -l 12 | tr -d '\n' | grep -qi "$EGON_HEX"
}

list_usb_disks() {
  lsblk -dnpo NAME,TRAN | awk '$2=="usb"{print $1}'
}

# ===== Auto-detect =====
if [ -z "$SRC" ]; then
  echo "==> Procurando pendrive Orange Pi (magic eGON.BT0)..."
  found=()
  for d in $(list_usb_disks); do
    if has_egon "$d"; then found+=("$d"); fi
  done
  case ${#found[@]} in
    0) echo "ERRO: nenhum pendrive USB com U-Boot Allwinner encontrado."; exit 1 ;;
    1) SRC=${found[0]}; echo "    fonte: $SRC" ;;
    *) echo "ERRO: múltiplos pendrives USB com U-Boot — especifica com --src"; printf '   %s\n' "${found[@]}"; exit 1 ;;
  esac
fi

if [ -z "$DST" ]; then
  echo "==> Procurando destino USB (≥ 4 GB, ≠ fonte)..."
  cand=()
  for d in $(list_usb_disks); do
    [ "$d" = "$SRC" ] && continue
    sz=$(lsblk -bdno SIZE "$d")
    [ "$sz" -ge $(( 4 * 1024**3 )) ] || continue
    cand+=("$d")
  done
  case ${#cand[@]} in
    0) echo "ERRO: nenhum destino USB ≥ 4 GB plugado."; exit 1 ;;
    1) DST=${cand[0]}; echo "    destino: $DST" ;;
    *) echo "ERRO: múltiplos destinos possíveis — especifica com --dst"; printf '   %s\n' "${cand[@]}"; exit 1 ;;
  esac
fi

# ===== Validações =====
[ -b "$SRC" ] || { echo "ERRO: $SRC não é block device"; exit 1; }
[ -b "$DST" ] || { echo "ERRO: $DST não é block device"; exit 1; }
[ "$SRC" != "$DST" ] || { echo "ERRO: fonte e destino são iguais"; exit 1; }
[ "$(lsblk -dno TRAN "$SRC")" = usb ] || { echo "ERRO: $SRC não é USB"; exit 1; }
[ "$(lsblk -dno TRAN "$DST")" = usb ] || { echo "ERRO: $DST não é USB"; exit 1; }
has_egon "$SRC" || { echo "ERRO: $SRC não tem U-Boot SPL no sector 16 (fonte inválida)"; exit 1; }

SRC_PART="${SRC}1"
DST_PART="${DST}1"
[ -b "$SRC_PART" ] || { echo "ERRO: $SRC_PART não existe"; exit 1; }

SRC_UUID=$(lsblk -no UUID "$SRC_PART" | head -1)
SRC_LABEL=$(lsblk -no LABEL "$SRC_PART" | head -1)
[ -n "$SRC_UUID" ] || { echo "ERRO: não consegui ler UUID de $SRC_PART"; exit 1; }

cat <<EOF
========================================================
CLONE ORANGE PI
--------------------------------------------------------
Fonte   (read-only): $SRC      $(lsblk -dno SIZE "$SRC")   UUID=$SRC_UUID
Destino (apagado):   $DST      $(lsblk -dno SIZE "$DST")   << TUDO SERÁ APAGADO
Partição nova:       sectors ${PART_START}..${PART_END}  (~7.2 GB)
${IMG:+Imagem .img:        $IMG}
========================================================
EOF

if [ "$ASSUME_YES" -ne 1 ]; then
  read -r -p "Digite 'sim' pra continuar: " ans
  [ "$ans" = "sim" ] || { echo "Abortado."; exit 0; }
fi

# ===== Setup work dir =====
WORK=$(mktemp -d /tmp/clone-cartao-XXXX)
trap 'sudo umount "$WORK/src" "$WORK/dst" 2>/dev/null || true; rm -rf "$WORK"' EXIT
SRC_MNT="$WORK/src"
DST_MNT="$WORK/dst"
PREBOOT="$WORK/uboot.bin"
mkdir -p "$SRC_MNT" "$DST_MNT"

# ===== Desmonta tudo =====
echo "==> Desmontando partições de $SRC e $DST..."
for d in "$SRC" "$DST"; do
  for p in $(lsblk -nrpo NAME "$d" | tail -n +2); do
    if mount | grep -q "^${p} "; then
      udisksctl unmount -b "$p" 2>/dev/null || sudo umount "$p" || true
    fi
  done
done

# ===== Captura U-Boot da fonte (read-only) =====
echo "==> Capturando região U-Boot de $SRC (sectors 16..8191)"
sudo dd if="$SRC" of="$PREBOOT" bs=512 skip=16 count=8176 status=none

# ===== Monta fonte READ-ONLY =====
echo "==> Montando $SRC_PART READ-ONLY"
sudo mount -o ro "$SRC_PART" "$SRC_MNT"

# ===== Limpa destino =====
echo "==> Limpando $DST"
sudo wipefs -af "$DST"
sudo dd if=/dev/zero of="$DST" bs=1M count=10 status=none

# ===== Cria partição no destino =====
echo "==> Criando partição em $DST (start=$PART_START, size=$PART_SECTORS)"
sudo sfdisk "$DST" >/dev/null <<EOF
label: dos
start=$PART_START, size=$PART_SECTORS, type=83
EOF
sudo partprobe "$DST"
sleep 2
[ -b "$DST_PART" ] || { echo "ERRO: $DST_PART não apareceu após partprobe"; exit 1; }

# ===== Escreve U-Boot no destino =====
echo "==> Escrevendo U-Boot em $DST sectors 16+"
sudo dd if="$PREBOOT" of="$DST" bs=512 seek=16 conv=notrunc status=none

# ===== Formata destino com mesma UUID =====
echo "==> Formatando $DST_PART (ext4, UUID=$SRC_UUID)"
sudo mkfs.ext4 -F -U "$SRC_UUID" ${SRC_LABEL:+-L "$SRC_LABEL"} "$DST_PART" >/dev/null

# ===== Copia arquivos =====
echo "==> Montando $DST_PART e rsync (preservando perms/ACL/xattr)"
sudo mount "$DST_PART" "$DST_MNT"
sudo rsync -aAXxH --numeric-ids --info=progress2 "$SRC_MNT/" "$DST_MNT/"
sudo sync

# ===== Verifica =====
echo "==> Verificando magic eGON.BT0 em $DST:"
sudo dd if="$DST" bs=512 skip=16 count=1 status=none | xxd | head -2
echo
echo "==> blkid do destino:"
sudo blkid "$DST_PART"

# ===== Desmonta =====
sudo umount "$SRC_MNT" "$DST_MNT"

# ===== Exporta .img opcional =====
if [ -n "$IMG" ]; then
  IMG_BYTES=$(( (PART_END + 1) * 512 ))
  IMG_BLOCKS=$(( (IMG_BYTES + 4*1024*1024 - 1) / (4*1024*1024) ))
  echo "==> Exportando .img ($IMG_BLOCKS blocos de 4M = ~7.6 GB) -> $IMG"
  sudo dd if="$DST" of="$IMG" bs=4M count="$IMG_BLOCKS" status=progress
  sudo chown "$USER:" "$IMG"
fi

echo
echo "==> Resultado:"
lsblk "$DST"
echo
echo "✅ Clone OK. $DST agora é bootável em Orange Pi 3 LTS."
echo "   Pra flashar em outro device: balenaEtcher (do .img) OU dd direto:"
echo "      sudo dd if=$DST of=/dev/sdX bs=4M status=progress"
