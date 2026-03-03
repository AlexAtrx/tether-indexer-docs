Avto Nariashvili
  Wednesday at 2:03 PM
Hello team
We’re seeing an issue where swap notifications get duplicated. It happens inconsistently, and we haven’t been able to reproduce it reliably. After extensive testing, I’m leaning toward the problem not being in the app itself, because even the swap completion notifications are duplicated and those aren’t triggered by the app.
Is there any scenario where an FCM token could be duplicated causing duplicated notifications? @Usman Khan

Usman Khan
  Wednesday at 2:06 PM
Not sure, I can ask someone to look into it. But if FCM token is duplicate for a user and that causes duplicate notifications, then shouldn't the same user consistently receive duplicate notifications? :thinking_face:

Avto Nariashvili
  Wednesday at 2:07 PM
yes, good point. so it cant be duplicated FCM token

