# xCam-RPI
Software for viewing multiple IP camera streams on RPI using only console.

1. Configuration is available in main file. It's simplified as much as it can be. Everything is being autodetected. In case ABS_X/ABS_Y is wrongly detected, You can set it manually.

2. Based on cameras count, software will automatically arrange videos on the screen.

3. It's prepared for touch screens, so when You click one of the streams, it will automatically go full screen.

4. If You don't have touch screen, run it with --notouch parameter.

5. Zooming camera after touch may take 2-3 seconds, that's normal, nothing to worry about.

6. Have fun, report bugs!

**How to configure crontab to automatically restart views in case of one will go offline + start xCam-RPI with system start.**
**Remember to set proper directory where xCam-RPI resides.**

`@reboot sleep 5; cd /home/pi/xCam-RPI; ./xCam-RPI.sh
* * * * * cd /home/pi/xCam-RPI; ./xCam-RPI.sh
* * * * * sleep 10; cd /home/pi/xCam-RPI; ./xCam-RPI.sh
* * * * * sleep 20; cd /home/pi/xCam-RPI; ./xCam-RPI.sh
* * * * * sleep 30; cd /home/pi/xCam-RPI; ./xCam-RPI.sh
* * * * * sleep 40; cd /home/pi/xCam-RPI; ./xCam-RPI.sh
* * * * * sleep 50; cd /home/pi/xCam-RPI; ./xCam-RPI.sh`
