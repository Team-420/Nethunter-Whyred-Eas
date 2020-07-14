#!/usr/bin/env bash

#Copyright (C) 2020 Shashank Baghel
#Personal kernel build script for https://github.com/theradcolor/android_kernel_xiaomi_whyred

#Set enviroment and vaiables
wd=$(pwd)
out="/mnt/kernels/android_kernel_xiaomi_whyred/out/"
BUILD="/mnt/kernels/android_kernel_xiaomi_whyred/"
ANYKERNEL_DIR_EAS="/home/theradcolor/whyred/anykernel-eas/"
ANYKERNEL_DIR_HMP="/home/theradcolor/whyred/anykernel-hmp/"
IMG="/mnt/kernels/android_kernel_xiaomi_whyred/out/arch/arm64/boot/Image.gz-dtb"
DATE=$(date +"%d-%m-%y")
BUILD_START=$(date +"%s")

#Define colors
red='\033[0;31m'
green='\e[0;32m'
white='\033[0m'

#Checkout build dir.
cd $BUILD

#Export build type
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ $BRANCH == "nethunter-hmp" ]; then
    export TYPE=hmp
elif [ $BRANCH == "nethunter-eas" ]; then
    export TYPE=eas
elif [ $BRANCH == "kernel-eas-oc" ]; then
    export TYPE=eas-oc
elif [ $BRANCH == "kernel-fakerad" ]; then
    export TYPE=fakerad
elif [ $BRANCH == "staging" ]; then
    export TYPE=staging
fi

function set_param()
{
    #Export compiler dir.
    CLANG_TRIPLE=aarch64-linux-gnu-
    GCC64=/mnt/kernels/clang11/gcc64/bin/aarch64-linux-android-
    GCC32=/mnt/kernels/clang11/gcc32/bin/arm-linux-androideabi-
    
    #Export ARCH <arm, arm64, x86, x86_64>
    export ARCH=arm64
    #Export SUBARCH <arm, arm64, x86, x86_64>
    export SUBARCH=arm64
    
    #CCACHE parameters
    ccache=$(which ccache)
    export USE_CCACHE=1
    export CCACHE_DIR="/mnt/kernels/android_kernel_xiaomi_whyred/.ccache"
    
    #kbuild host and user
    export KBUILD_BUILD_USER="S133PY"
    export KBUILD_BUILD_HOST="Kali"
    
    #Compiler String
    CC="${ccache} /mnt/kernels/clang11/bin/clang"
    export KBUILD_COMPILER_STRING="$(${CC} --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')"
}


function build_clang()
{
    set_param
    make O=$out clean
    make O=$out mrproper
    rm -rf $out/arch/arm64/boot
    make O=$out whyred-perf_defconfig

    make O=$out CC="${CC}" \
    CROSS_COMPILE="${GCC64}" \
    CROSS_COMPILE_ARM32="${GCC32}" \
    CLANG_TRIPLE="${CLANG_TRIPLE}" \
    -j6  2>&1| tee $out/kernel.log
    
    if [ -f $IMG ]; then
        BUILD_END=$(date +"%s")
        DIFF=$(($BUILD_END - $BUILD_START))
        echo -e $green"Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."$green
        flash_zip
    else
		echo -e $red"Build failed, please fix the errors first bish!"$red
	fi
}

function flash_zip()
{
    echo -e $green"Now making a flashable zip of kernel with AnyKernel3"$white

    if [ $TYPE == "hmp" ]; then
        cd $ANYKERNEL_DIR_HMP
        export AK3_DIR="/mnt/kernels/android_kernel_xiaomi_whyred/anykernel-hmp/"
    elif [ $TYPE == "eas" ]; then
        cd $ANYKERNEL_DIR_EAS
        export AK3_DIR="/mnt/kernels/android_kernel_xiaomi_whyred/anykernel-eas/"
    elif [ $TYPE == "eas-oc" ]; then
        cd $ANYKERNEL_DIR_EAS
        export AK3_DIR="/mnt/kernels/android_kernel_xiaomi_whyred/anykernel-eas/"
    elif [ $TYPE == "fakerad" ]; then
        cd $ANYKERNEL_DIR_EAS
        export AK3_DIR="/mnt/kernels/android_kernel_xiaomi_whyred/anykernel-eas/"
    else 
        cd $ANYKERNEL_DIR_EAS
        export AK3_DIR="/mnt/kernels/android_kernel_xiaomi_whyred/anykernel-eas/"
    fi

    check_camera
    export ZIPNAME=rad-$TYPE-$CAM_TYPE-whyred.zip

    #Cleanup and copy Image.gz-dtb to dir.
    rm -f *.zip
    rm -f Image.gz-dtb
    cp $out/arch/arm64/boot/Image.gz-dtb ${AK3_DIR}/

    #Build a flashable zip
    zip -r9 $ZIPNAME * -x README.md .git
}

function check_camera()
{
    CAMERA="$(grep 'BLOBS' $BUILD/arch/arm64/configs/whyred-perf_defconfig)"
    if [ $CAMERA == "CONFIG_XIAOMI_NEW_CAMERA_BLOBS=y" ]; then
            CAM_TYPE="newcam"
        elif [ $CAMERA == "CONFIG_XIAOMI_NEW_CAMERA_BLOBS=n" ]; then
            CAM_TYPE="oldcam"
    fi
}

function change_camera()
{
    check_camera
    if [ $CAM_TYPE == "newcam" ]; then
        PATCH="CONFIG_XIAOMI_NEW_CAMERA_BLOBS=n"
    elif [ $CAM_TYPE == "oldcam" ]; then
        PATCH="CONFIG_XIAOMI_NEW_CAMERA_BLOBS=y"
    fi
    
    #Change the compability
    sed -i 's/'"$CAMERA"/"$PATCH"'/g' $BUILD/arch/arm64/configs/whyred-perf_defconfig
    
    AFTER_PATCH="$(grep 'BLOBS' $BUILD/arch/arm64/configs/whyred-perf_defconfig)"
    if [ $AFTER_PATCH == "CONFIG_XIAOMI_NEW_CAMERA_BLOBS=y" ]; then
        echo -e $green"Changed compability for NEW camera blobs!"$white
    elif [ $AFTER_PATCH == "CONFIG_XIAOMI_NEW_CAMERA_BLOBS=n" ]; then
        echo -e $green"Changed compability for OLD camera blobs!"$white
    fi
}

build_clang