Alex [0:45]: yes
Alex [0:49]: sorry yeah i can hear you very well
Them [0:51]: perfect
Them [0:53]: so let me share my screen
Them [1:01]: we are getting another issue related to mongodb
Them [1:08]: so i thought maybe i can spin it by you and show you the issue itself
Them [1:21]: so the issue the error that we're getting is that we have this log pool was force destroyed
Them [1:26]: do you know about this error or have you encountered it before
Them [1:34]: if you're saying something
Alex [1:39]: yeah do you hear me
Alex [1:39]: that
Them [1:42]: yeah i can hear you
Alex [1:46]: yeah the logo actually does show this
Alex [1:54]: i think this typically indicates that mongodb connection pool is basically being torn down
Alex [1:56]: in an unexpected way
Alex [2:09]: so this is like to my knowledge this is often you happen to drive a driver connect storm where basically the network is receivable
Alex [2:14]: or maybe there is unhandled asynchronous speed of the node js application
Them [2:32]: so the strange part that i'm noticing about this is that it's not related to any specific right request it's specific for this error is happening or like most of the time this error is happening
Them [2:36]: during the read request that we're making
Them [2:44]: and i also wanted to show you this part i'm not sure if
Them [2:52]: it makes sense i'm noticing that in terms of so this is mongo's dashboard that we have
Them [3:01]: and it connections over here are close to two thousand and they remain
Alex [3:01]: two thousand
Them [3:07]: is this normal or is this something that we should investigate why we have so many open connections
Alex [3:18]: yeah this thousand basically aren't really see there is a production rotation
Them [3:21]: so this one is production
Alex [3:32]: yeah well production is naturally like normally abnormal if you have multiple apps instances or high temperature workout like this is not a block
Alex [3:34]: maybe it was checking
Alex [3:35]: yeah
Them [3:39]: so you just wanted to mention that for this one
Them [3:43]: we probably have fewer users
Them [3:47]: on production right now compared to the phasing environment
Alex [3:49]: yeah
Alex [3:55]: maybe it's worth a check if the pool size basically is capped for instance
Alex [4:03]: so if it service replica maintains its own pool the total can easily add up
Alex [4:06]: i think what makes the matter basically
Alex [4:12]: like more important is whether these connections are active or idle
Alex [4:16]: and if the driver is basically recycling them properly or not
Them [4:27]: and do we get this information over here or is this something that we need to
Alex [4:27]: have
Them [4:31]: some information
Them [4:46]: on database connection directly to get this information
Alex [4:46]: i think we can get the partial visibility here but for detailed connection like a state like active versus idle versus idle i would need to basically
Alex [4:51]: to enable the mongodb like connection pool states
Alex [5:00]: the conduction policy it is what really tell us exactly what's going on which is a command to use in the driver connection monitoring hooks
Alex [5:07]: so that will show whether the pools are being used or recreated too frequently
Them [5:14]: okay so
Them [5:27]: i'm kind of lost on this particular issue so i don't know if you finished working on the redis work or not but this one i think is more important and has more priority
Them [5:34]: so could you investigate this like why the pool might be getting destroyed
Them [5:41]: and what might be the dashboard we have configured a super
Them [5:52]: frustrating to use but anyway so like i will share with you a list of logs that i'm noticing in the production environment
Them [5:55]: and you can investigate
Them [5:59]: what might be causing them
Them [6:09]: and what exactly do we need to run on the production so that we can talk with andre and he can give us more information about it as well
Them [6:18]: does that make sense to you
Alex [6:18]: yeah sure sure please send me the logs and i'll start by basically correlating the time information
Alex [6:35]: i also run like the b run command with some time consuming but then again i need actually production instances if this is possible or i have to push code into production is that possible
Them [6:58]: no so i don't have access to production code like production instances or production server so we have to talk to andre and share with him the details or like theories that we want to run then he'll be able to run them and get back to us with multiple
Alex [7:07]: okay i get it all right i'll prepare a short list of basically they are nested commands and metrics so we can basically perform like a production
Them [7:18]: yeah
Them [7:18]: so i've shared with you the logs that are basically happening on this particular machine
Them [7:21]: on the production servers and you can review them
Them [7:42]: and see what might be causing you this is just one of the just the errors that happened in the last three hours but i think if we go a little bit more into the history then this will be happening much longer as well
Them [7:55]: just investigate this and let me know if you need anything specifically from my
Them [7:55]: as well i'll create a file and i will share it with you okay
Alex [8:03]: all right perfect i'll give you to let you know and for the british prs i already read them you can see
Them [8:05]: okay okay so i will just review them
Them [8:07]: thank you
Them [8:09]: perfect
Them [8:11]: bye