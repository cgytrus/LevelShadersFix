# Level Shaders Fix
Fixes a major performance issue with 2.2 shader triggers.
That's caused by the shaders being rendered at 2608x2608 at 16:9 aspect ratio on high graphics,
1304x1304 on medium and 652x652 on low. Thanks, Robert Nicholas Christian Topala.

This mod will make shaders render at your native screen resolution instead.

To fix scaling artifacts when scaling the absolutely massive texture down, RobTop added
antialiasing (and an option to turn it off). This mod doesn't implement it,
as it's no longer needed (and the option doesn't do anything anymore too).

huge thanks to **cookiaria** for help with testing !!!!!
