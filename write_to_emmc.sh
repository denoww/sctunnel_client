
#!/bin/bash

sudo dd if=/usr/lib/u-boot/orangepi_3b/u-boot-sunxi-with-spl.bin of=/dev/mmcblk2 bs=1024 seek=8
sync
