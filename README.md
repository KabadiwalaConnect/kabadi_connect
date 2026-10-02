Kabadi Connect
A small Android app for the people who collect our old scrap.

In India, most old things - newspapers, iron, copper, old phones, broken TVs - do not go straight to a factory. A person with a cart or a small shop, we call them kabadiwala, buys them from our houses. Then that person sells them to a bigger buyer. The problem is, the kabadiwala never knows the right price, and does not know which buyers are safe and allowed by the government. So good material gets wasted, and sometimes burned or broken in unsafe ways.

Kabadi Connect is our small try to fix this. It is a bridge between the collector and the proper recycling world.

What the app does, in one line
A collector tells the app "I have 10 kg of copper wire in Ludhiana", and the app helps the right buyer see it, give a price, and meet for the handover. Everything gets written down, so both sides can trust it.

Who uses it
There are three kinds of users.

Collector - the person who collects scrap. Joins with just a phone number and a PIN. No documents needed to start.
Recycler - the buyer. The admin checks them before they can give prices, so collectors only talk to safe buyers.
Admin - our team. We run a small web page to check recyclers, publish a price board, and keep things clean.
How one sale happens
Step 1. The collector opens the app and taps what they have, like "Copper", and says the weight.

Step 2. The app shows today's price board, so they know a fair range. A voice reads it out in Hindi, Marathi or English.

Step 3. The collector publishes the lot. Verified buyers see it.

Step 4. Buyers send their price per kg.

Step 5. The collector picks one buyer. Both agree on a time and place.

Step 6. At the meeting they weigh the material. Both confirm the final weight and price in the app, and the sale is recorded. The money is paid in cash, like it always was. The app does not touch the money.

Things we made on purpose
Works without internet most of the time. Data stays on the phone and goes online when the net comes back.
Big buttons and pictures, so reading is not needed. A voice speaks every screen.
One phone, whole family. Each lot can carry a family member's name.
A monthly thank-you board. Top collectors get their name and city shown. Rewards are given in person, never through the app.
A small AI that looks at a photo of the scrap and guesses what it might be. It is only a helper. The person always has the final say.
Things we did not put in the app, and why
No money transfer. Cash between people is how this world already works. We only write the record.
No ID papers for collectors at signup. Asking for papers first would stop the very people we want to help.
Nothing automatic from the AI. A wrong guess by a machine should never decide a person's money.
What we used to build it
Flutter, for the Android app
Firebase for login, the database (Cloud Firestore), and the safety rules
A tiny image model made with Teachable Machine, running on the phone with TensorFlow Lite
One plain web page for the admin, also hosted on Firebase
How the data is stored, short version
text

users/               one document per person
  lots/              what the collector has to sell
sellRequests/        the published lot, open for offers
  quotes/            the prices buyers send
  handover/          the final weighing at the meeting
  receipts/          the cash record after the sale
priceBoard/          rates published by the admin
leaderboard/         monthly list of top collectors
Every rule is written so a user can only touch their own things. A normal user can never make themselves an admin, and a buyer can never approve themselves.

How to run it
Install Flutter on your computer.
Make your own Firebase project and put your google-services.json in android/app. We cannot share ours, since it is tied to our account.
Publish the Firestore rules from the admin folder in your Firebase console.
Connect a phone and run flutter run.
If the Firebase setup is missing, the app will not start. That is on purpose.

Where the project stands today
The full flow (collector, buyer, admin) runs on a real phone and has been tested by hand, many times.
The AI photo helper works on a small photo set we collected ourselves, and it says so when it is not sure.
We are meeting real working collectors in Ludhiana before our final round, and we will fix what they tell us.
What comes next
Feedback visits with real collectors
More cities and more materials
A bigger photo set, so the helper gets better
A price history, so the board learns over time
Team
Team Mystic Minds
Smart India Hackathon 2026

A small honest note
We are students. This is a working prototype, not a finished company. Anything you see inside the app is from our own test runs, not made-up numbers. If something here is wrong or hard to understand, please open an issue and tell us. We will learn from it.
