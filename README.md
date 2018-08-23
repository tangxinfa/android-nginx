`android-nginx` Cross compile nginx with android ndk.

When cross compile nginx, require connect the device for run feature test
progrom, set `CROSS_COMPILE_DEVICE_IP` environment variable to the device ip:

    export CROSS_COMPILE_DEVICE_IP=192.168.1.3

Start build with docker:

    make

Build output:

    output/sbin/nginx
