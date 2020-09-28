#!/usr/bin/env bash

# Copyright (C) 2020 Shashank Baghel
# Personal kernel CI build script for https://github.com/theradcolor/android_kernel_xiaomi_whyred

# Set enviroment and vaiables
wd=$(pwd)
out=$wd"/out"
KERNEL_DIR=$wd
ANYKERNEL_DIR=$wd"/AnyKernel3"
IMG=$out"/arch/arm64/boot/Image.gz-dtb"
DATE="`date +%d%m%Y-%H%M%S`"
grp_chat_id="-1001355665867"
chat_id="-1001355665867"
token="1254837116:AAEjAUEGeb3X4W8L5WqnJTDqG6I6ADyk6kI"

# Define colors
red='\033[0;31m'
green='\e[0;32m'
white='\033[0m'

function clone()
{
    git clone --depth=1 --quiet https://github.com/theradcolor/clang
    git clone --depth=1 --quiet https://github.com/theradcolor/AnyKernel3 -b ak-cci
}

function checkout_source()
{
    # Checkout to kernel source
    cd "${KERNEL_DIR}"
}

function set_param_clang()
{
    # Export ARCH <arm, arm64, x86, x86_64>
    export ARCH=arm64
    #Export SUBARCH <arm, arm64, x86, x86_64>
    export SUBARCH=arm64

    # Kbuild host and user
    export KBUILD_BUILD_USER="S133PY"
    export KBUILD_BUILD_HOST="kali"
    export KBUILD_JOBS="$((`grep -c '^processor' /proc/cpuinfo` * 2))"

    # Compiler
    GCC32=$wd/clang/bin/arm-linux-gnueabi-
    GCC64=$wd/clang/bin/aarch64-linux-gnu-
    GCC64_TYPE=aarch64-linux-gnu-

    # Compiler String
    CLANG=$wd/clang/bin/clang
    COMPILER_STRING="$(${CLANG} --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' | sed 's/ *$//')"
    export KBUILD_COMPILER_STRING="${COMPILER_STRING}"
}

function build_clang()
{
    
    make O="$out" $config

    BUILD_START=$(date +"%s")

    make -j"${KBUILD_JOBS}" O=$out CC="${CLANG}" AR="llvm-ar" NM="llvm-nm" OBJCOPY="llvm-objcopy" OBJDUMP="llvm-objdump" STRIP="llvm-strip" CROSS_COMPILE="${GCC64}" CROSS_COMPILE_ARM32="${GCC32}" CLANG_TRIPLE="${GCC64_TYPE}"  2>&1| tee $out/build.log
    make -j"${KBUILD_JOBS}" O=$out CC="${CLANG}" AR="llvm-ar" NM="llvm-nm" OBJCOPY="llvm-objcopy" OBJDUMP="llvm-objdump" STRIP="llvm-strip" CROSS_COMPILE="${GCC64}" CROSS_COMPILE_ARM32="${GCC32}" CLANG_TRIPLE="${GCC64_TYPE}" modules_install INSTALL_MOD_PATH=modules_out 
    BUILD_END=$(date +"%s")
    DIFF=$(($BUILD_END - $BUILD_START))

    if [ -f "${IMG}" ]; then
        echo -e $green"Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)."$green
        flash_zip
    else
        tg_push_error
        echo -e $red"Build failed, please fix the errors first bish!"$red
    fi
}

function flash_zip()
{
    echo -e $green"Now making a flashable zip of kernel with AnyKernel3"$white

    check_build_type
    check_camera
    export ZIPNAME=Team420-NH-$TYPE-$CAM_TYPE-$DATE.zip

    # Checkout anykernel3 dir
    cd "$ANYKERNEL_DIR"
    # Patch anykernel3
    patch_anykernel

    # Cleanup and copy Image.gz-dtb to dir.
    rm -f Team420-NH*.zip
    rm -f Image.gz-dtb

    # Copy Image.gz-dtb to dir.
    cp $out/arch/arm64/boot/Image.gz-dtb ${ANYKERNEL_DIR}/

    # Build a flashable zip
    zip -r9 $ZIPNAME * -x README.md .git
    MD5=$(md5sum Team420-NH-*.zip | cut -d' ' -f1)
    tg_push
}

function check_camera()
{
    CAMERA="$(grep 'BLOBS' $KERNEL_DIR/arch/arm64/configs/$config)"
    if [ $CAMERA == "CONFIG_XIAOMI_NEW_CAMERA_BLOBS=y" ]; then
            CAM_TYPE="newcam"
        elif [ $CAMERA == "CONFIG_XIAOMI_NEW_CAMERA_BLOBS=n" ]; then
            CAM_TYPE="oldcam"
    fi
}

function check_build_type()
{
    BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    if [ $BRANCH == "kernel-hmp" ]; then
        export TYPE=hmp
    elif [ $BRANCH == "kernel-eas" ]; then
        export TYPE=eas
    elif [ $BRANCH == "staging-hmp" ]; then
        export TYPE=staging-hmp
    elif [ $BRANCH == "staging-eas" ]; then
        export TYPE=staging-eas
    else
        export TYPE=$BRANCH
    fi
}

function tg_inform()
{
    curl -s -X POST https://api.telegram.org/bot$token/sendMessage?chat_id=$chat_id -d "disable_web_page_preview=true" -d "parse_mode=html&text=<b>⚒️ New CI build has been triggered"'!'" ⚒️</b>%0A%0A<b>Linux Version • </b><code>$(make kernelversion)</code>%0A<b>Git branch • </b><code>$(git rev-parse --abbrev-ref HEAD)</code>%0A<b>Commit head • </b><code>$(git log --pretty=format:'%h : %s' -1)</code>%0A<b>Compiler • </b><code>${COMPILER_STRING}</code>%0A<b>At • </b><code>$(TZ=Asia/Kolkata date)</code>%0A"
}

function tg_push()
{
    ZIP="${ANYKERNEL_DIR}"/$(echo Team420-NH-*.zip)
    curl -F document=@"${ZIP}" "https://api.telegram.org/bot$token/sendDocument" \
            -F chat_id="$chat_id" \
            -F "disable_web_page_preview=true" \
            -F "parse_mode=html" \
            -F caption="⭕️ Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s) | <b>MD5 checksum</b> • <code>${MD5}</code>"
}

function tg_push_error()
{
    curl -s -X POST https://api.telegram.org/bot$token/sendMessage?chat_id=$chat_id -d "disable_web_page_preview=true" -d "parse_mode=html&text=<b>❌ Build failed after $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s).</b>"
}

function tg_push_log()
{
    LOG=$KERNEL_DIR/build.log
    curl -F document=@"${LOG}" "https://api.telegram.org/bot$token/sendDocument" \
            -F chat_id="$grp_chat_id" \
            -F "disable_web_page_preview=true" \
            -F "parse_mode=html" \
            -F caption="⭕️ Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)."
}

function patch_anykernel()
{
    if [ $TYPE == "eas" ]; then
        curl https://raw.githubusercontent.com/theradcolor/patches/master/0001-anykernel3-add-our-init.rc-script-to-execute-on-boot-eas.patch | git am
        rm -rf *.patch
    elif [ $TYPE == "hmp" ]; then
        curl https://raw.githubusercontent.com/theradcolor/patches/master/0001-anykernel3-add-our-init.rc-script-to-execute-on-boot-hmp.patch | git am
        rm -rf *.patch
    elif [ $TYPE == "staging-eas" ]; then
        curl https://raw.githubusercontent.com/theradcolor/patches/master/0001-anykernel3-add-our-init.rc-script-to-execute-on-boot-eas.patch | git am
        rm -rf *.patch
    elif [ $TYPE == "staging-hmp" ]; then
        curl https://raw.githubusercontent.com/theradcolor/patches/master/0001-anykernel3-add-our-init.rc-script-to-execute-on-boot-hmp.patch | git am
        rm -rf *.patch
    else
        echo "Type not mentioned, skipping patches!"
    fi
}

# Configure git
git config --global user.name "Thiviyan"
git config --global user.email "thiviyan@gmail.com"
# Clone the toolchains
clone
# Checkout to source
checkout_source
# Configure enviroments
set_param_clang
if [[ "$@" =~ "newcam" ]]; then
    config="whyred-newcam-nh_defconfig"
else
    config="whyred-nh_defconfig"
    # Push build message to telegram
    tg_inform
fi
# Start Build
build_clang
# Post build logs
tg_push_log
