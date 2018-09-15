`android-nginx` Cross compile nginx with android ndk.

When cross compile nginx, require connect the device for run feature test
progrom. Your host must have permission to `adb connect` the device, then set
`CROSS_COMPILE_DEVICE_IP` environment variable to the device ip, such as

    export CROSS_COMPILE_DEVICE_IP=192.168.1.3

Start cross compile nginx with docker:

    make

Build output:

    output/sbin/nginx
