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
grp_chat_id="-1001375712567"
chat_id="-1001355665867"
token="1254837116:$token"

function clone_clang()
{
    git clone --depth=1 --quiet https://github.com/kdrag0n/proton-clang clang
    git clone --depth=1 --quiet https://github.com/theradcolor/AnyKernel3 -b ak-cci
}

function clone_gcc()
{
    git clone --depth=1 --quiet https://github.com/theradcolor/arm-linux-gnueabi gcc32
    git clone --depth=1 --quiet https://github.com/theradcolor/aarch64-linux-gnu gcc64
    git clone --depth=1 --quiet https://github.com/theradcolor/AnyKernel3 -b ak-cci
}

function checkout_source()
{
    # Checkout to kernel source
    cd "${KERNEL_DIR}"
}

function set_param_gcc()
{
    #Export compiler dir.
    export CROSS_COMPILE=$wd"/gcc64/bin/aarch64-linux-gnu-"
    export CROSS_COMPILE_ARM32=$wd"/gcc32/bin/arm-linux-gnueabi-"

    # Export ARCH <arm, arm64, x86, x86_64>
    export ARCH=arm64
    #Export SUBARCH <arm, arm64, x86, x86_64>
    export SUBARCH=arm64

    # Kbuild host and user
    export KBUILD_BUILD_USER="S133PY"
    export KBUILD_BUILD_HOST="Kali"
    export KBUILD_JOBS="$((`grep -c '^processor' /proc/cpuinfo` * 2))"

    TC=$wd/gcc64/bin/aarch64-linux-gnu-gcc
    COMPILER_STRING="$(${wd}"/gcc64/bin/aarch64-linux-gnu-gcc" --version | head -n 1)"
    export KBUILD_COMPILER_STRING="${COMPILER_STRING}"
}

function set_param_clang()
{
    # Export ARCH <arm, arm64, x86, x86_64>
    export ARCH=arm64
    #Export SUBARCH <arm, arm64, x86, x86_64>
    export SUBARCH=arm64

    # Kbuild host and user
    export KBUILD_BUILD_USER="S133PY"
    export KBUILD_BUILD_HOST="Kali"
    export KBUILD_JOBS="$((`grep -c '^processor' /proc/cpuinfo` * 2))"

    # Compiler
    GCC32=$wd/clang/bin/arm-linux-gnueabi-
    GCC64=$wd/clang/bin/aarch64-linux-gnu-
    GCC64_TYPE=aarch64-linux-gnu-

    # Compiler String
    TC=$wd/clang/bin/clang
    CLANG_DIR=$wd/clang
    COMPILER_STRING="$(${TC} --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' | sed 's/ *$//')"
    export KBUILD_COMPILER_STRING="${COMPILER_STRING}"
}


function build_gcc()
{
    clone_gcc
    checkout_source
    set_param_gcc
    # Push build message to telegram
    tg_inform

    make O="${out}" clean
    make O="${out}" mrproper
    rm -rf "${out}"/arch/arm64/boot
    make O="${out}" "${config}"

    BUILD_START=$(date +"%s")
    make O="${out}" -j"${KBUILD_JOBS}" 2>&1| tee "${out}"/build.log
    
    BUILD_END=$(date +"%s")
    DIFF=$(($BUILD_END - $BUILD_START))

    if [ -f "${IMG}" ]; then
        echo -e "Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)."
        flash_zip
    else
        tg_push_error
    echo -e "Build failed, please fix the errors first bish!"
  fi
}

function build_clang()
{
    clone_clang
    checkout_source
    set_param_clang
    # Push build message to telegram
    tg_inform


    make O="$out" $config

    BUILD_START=$(date +"%s")

    make -j"${KBUILD_JOBS}" O=$out CC="${TC}" LLVM_AR="${CLANG_DIR}/bin/llvm-ar" LLVM_NM="${CLANG_DIR}/bin/llvm-nm" OBJCOPY="${CLANG_DIR}/bin/llvm-objcopy" OBJDUMP="${CLANG_DIR}/bin/llvm-objdump" STRIP="${CLANG_DIR}/bin/llvm-strip" CROSS_COMPILE="${GCC64}" CROSS_COMPILE_ARM32="${GCC32}" CLANG_TRIPLE="${GCC64_TYPE}" 2>&1| tee $out/build.log

    BUILD_END=$(date +"%s")
    DIFF=$(($BUILD_END - $BUILD_START))

    if [ -f "${IMG}" ]; then
        echo -e "Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)."
        flash_zip
    else
        tg_push_error
    echo -e "Build failed, please fix the errors first bish!"
  fi
}

function flash_zip()
{
    echo -e "Now making a flashable zip of kernel with AnyKernel3"

    check_build_type
    check_camera
    export ZIPNAME=Team420-$TYPE-$CAM_TYPE-$DATE.zip

    # Checkout anykernel3 dir
    cd "$ANYKERNEL_DIR"
    # Patch anykernel3
    patch_anykernel

    # Cleanup and copy Image.gz-dtb to dir.
    rm -f rad-ci*.zip
    rm -f Image.gz-dtb

    # Copy Image.gz-dtb to dir.
    cp $out/arch/arm64/boot/Image.gz-dtb ${ANYKERNEL_DIR}/

    # Build a flashable zip
    zip -r9 $ZIPNAME * -x README.md .git
    MD5=$(md5sum rad-ci-*.zip | cut -d' ' -f1)
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
    if [ ${config} == "whyred-nh_defconfig" ]; then
        curl -s -X POST https://api.telegram.org/bot$token/sendMessage?chat_id=$chat_id -d "disable_web_page_preview=true" -d "parse_mode=html&text=<b>⚒️ New CI build has been triggered"'!'" ⚒️</b>%0A%0A<b>Linux Version • </b><code>$(make kernelversion)</code>%0A<b>Git branch • </b><code>$(git rev-parse --abbrev-ref HEAD)</code>%0A<b>Commit head • </b><code>$(git log --pretty=format:'%h : %s' -1)</code>%0A<b>Compiler • </b><code>$(${TC} --version | head -n 1)</code>%0A<b>At • </b><code>$(TZ=Asia/Kolkata date)</code>%0A"
    fi
}

function tg_push()
{
    ZIP="${ANYKERNEL_DIR}"/$(echo rad-ci-*.zip)
    curl -F document=@"${ZIP}" "https://api.telegram.org/bot${token}/sendDocument" \
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
            -F caption="⭕️ Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). @theradcolor"
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
git config --global user.name "Thiviyan Vivekananthan"
git config --global user.email "thiviyan@gmail.com"
if [[ "$@" =~ "newcam" ]]; then
    config="whyred-nh-newcam_defconfig"
else
    config="whyred-nh_defconfig"
fi
# Start Build (build_clang or build_gcc)
build_clang
# build_gcc
# Post build logs
tg_push_log