import 'package:flutter/material.dart';
import '../theme.dart';

/// The privacy notice, and the participant information sheet for the test.
///
/// The website has carried this at web/privacy.html since 5 September. The
/// app had nothing at all, which mattered more than it sounds: a tester who
/// only ever opens the phone is asked for the same browsing record, the same
/// bank transfer receipt and the same photographs of their computer as a
/// tester on the website, and was never shown a word about any of it.
///
/// The wording below is the website's, changed only where the platform makes
/// it untrue -- "this app" for "this site", and the device's own storage for
/// the browser's. Anything that changes what is actually collected has to be
/// changed in both places or the two stop agreeing, and the one a participant
/// was shown becomes a matter of which device they happened to pick up.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const String lastUpdated = '22 September 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Notice')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
        children: [
          const Text(
            'Privacy Notice',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.ink),
          ),
          const SizedBox(height: 4),
          Text('Last updated $lastUpdated',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 18),

          _callout(
            'This app is a student final-year project. eTech Computer '
            'Accessories is being built and tested as university coursework. '
            'No goods are shipped, and during the test period you are asked '
            'not to send any money — the payment details shown at the '
            'checkout are placeholders and are not a real account. During the '
            'test period the app records how it is used, and this page '
            'explains exactly what that means.',
          ),

          _h('Who is responsible'),
          _p('This app is operated by a student at a Malaysian university as '
              'part of a final-year project, supervised by an academic '
              'supervisor. Questions about anything on this page, including a '
              'request to see or delete your data, can be sent through the '
              'Contact page on the website.'),

          _h('What is recorded, and why'),
          _p('If you create an account, we store your name, email address '
              'and phone number. These are needed to hold your basket, show '
              'your order history, and tell you when an order is ready. Your '
              'profile also has an address box, which is optional — it saves '
              'typing if you choose delivery, and you can leave it empty and '
              'collect instead. Your password is held by Supabase Auth as a '
              'hash — the shop never sees or stores the password itself.'),
          _p('Whether or not you sign in, the app records:'),
          _bullets(const [
            'which products you open, and when;',
            'what you type into the search box, and how many results came back;',
            'what you ask the chatbot, and what it answered;',
            'what you add to your basket, wishlist, and what you order.',
          ]),
          _p('This is the point of the project rather than a side effect. The '
              'research question is whether a shop\'s own records can be used '
              'to recommend products and forecast stock, so the browsing '
              'record is the subject being studied. It is used to show the '
              'shop\'s staff which products customers are interested in, to '
              'decide who is told when one of those products goes on offer '
              '(see "Messages we send you" below), to suggest items on the '
              'home page, and — in aggregate, with no names attached — as the '
              'dataset analysed in the written dissertation.'),

          _h('Being recognised without being identified'),
          _p('If you browse without signing in, your device is given a random '
              'identifier (a UUID) that is stored on this device and sent with '
              'the records above. It is not a login, it proves nothing, and it '
              'is not linked to your name, email or any other person — it only '
              'answers the question "was this the same device?", so that a '
              'single visit can be read as one visit rather than as a heap of '
              'unrelated taps.'),
          _p('If you later create an account or sign in, the activity recorded '
              'under that identifier on this device is attached to your '
              'account, so that a purchase can be read together with the '
              'browsing that led to it. Clearing the app\'s storage, or '
              'uninstalling it, ends the old identifier and starts a new one.'),

          _h('If you place an order'),
          _p('An order records the items, the total, and the name and phone '
              'number you type at checkout. That is kept for as long as the '
              'order record exists, because it is the order.'),
          _p('An address is recorded only if you choose delivery. If you '
              'choose to collect, no address is asked for, and any address '
              'the app happens to send with the order is discarded before it '
              'is stored — the phone number is how we tell you it is ready.'),
          _p('There is no card payment in this app and no payment gateway. '
              'Instead the checkout shows bank details and asks you to upload '
              'a photograph of the transfer receipt, which a member of staff '
              'then checks. If you upload one, we store that image. A receipt '
              'normally shows a name, an account or reference number and an '
              'amount, so please treat it the way you would treat any bank '
              'document.'),
          _bullets(const [
            'Receipt images are stored in a private area. They are readable '
                'only by you and by the shop\'s staff — not by other '
                'customers, and not by anybody without an account.',
            'They are not part of the research dataset and are not used in '
                'the dissertation.',
            'You can ask for yours to be deleted through the Contact page.',
            'During the test period there is nothing to pay, so there should '
                'be no receipt to send. Please do not upload a real bank '
                'document unless you actually intend to.',
          ]),

          _h('Messages we send you'),
          _p('If you have an account, the shop sends you short messages. They '
              'appear under the bell in this app and on the website, and — if '
              'you allow this app to send notifications — on your phone as '
              'well. To reach your phone, the app stores a delivery token for '
              'this device; it is removed when you sign out. There are two '
              'kinds:'),
          _bullets(const [
            'Order updates: when your payment is approved or rejected, and '
                'when your order is ready to collect or has been sent.',
            'Offers on things you showed interest in: when the shop puts a '
                'product on a timed deal, a message goes to signed-in '
                'customers who saved it to their wishlist, added it to their '
                'basket without buying it, or opened it three or more times. '
                'Who receives it is worked out automatically from the browsing '
                'record described above; staff choose which product goes on '
                'offer, not who is told. If you browse without signing in, you '
                'are never sent one.',
          ]),
          _p('For every message we record when it was sent and whether, and '
              'when, you opened it. For offer messages we also look at whether '
              'you viewed or bought that product in the seven days afterwards. '
              'This is part of the research: it measures whether offers chosen '
              'from browsing are of any use to the people who get them, and it '
              'appears in the dissertation only as totals, with no names '
              'attached.'),
          _p('You can turn notifications off for this app in your phone\'s '
              'settings at any time; the messages still wait under the bell. '
              'If you would rather not receive offer messages at all, say so '
              'through the Contact page on the website and they will stop.'),

          _h('If we contact you on WhatsApp'),
          _p('The phone number you give at checkout may be used to message you '
              'on WhatsApp about that order — usually to confirm we have '
              'received your payment, or to ask for a clearer receipt. A '
              'member of staff writes and sends those messages; nothing is '
              'sent automatically.'),
          _p('WhatsApp is run by Meta, not by us. Anything you send or receive '
              'there goes through their service under their privacy policy, '
              'and a conversation stays on their servers and on your phone '
              'after the order is finished. If you would rather we did not use '
              'WhatsApp, say so and we will use email instead. You never have '
              'to start a WhatsApp conversation to buy anything — the receipt '
              'upload does the same job.'),

          _h('If you submit a build to the showcase'),
          _p('The Rigs screen lets you send in photographs of a computer you '
              'have built, with the parts tagged. If you do, those photographs '
              'and your first name are published there once a member of staff '
              'has approved them. Submitting is entirely optional, and you can '
              'ask for a submission to be removed at any time.'),

          _h('What is not recorded'),
          _bullets(const [
            'No card, bank or payment credentials. There is no card box in '
                'this app and no payment is processed here.',
            'No advertising or third-party analytics trackers, and nothing is '
                'sold or passed to advertisers.',
            'No tracking cookies. The app keeps your sign-in token and the '
                'device identifier in the device\'s own storage.',
          ]),

          _h('Where it is kept, and who can see it'),
          _p('Everything is stored in a Supabase (PostgreSQL) database. Access '
              'is restricted by database policies: you can read your own '
              'account and your own orders and nothing else, and the browsing '
              'records can be read only by shop staff. Questions sent to the '
              'AI assistant are passed to Google\'s Gemini API to generate a '
              'reply; the shop\'s product catalogue and your message are sent, '
              'and your name, email and account details are not.'),

          _h('How long it is kept'),
          _p('Account and order records are kept while the account exists. '
              'Browsing, search and chatbot records are kept for the duration '
              'of the project and the assessment that follows it, after which '
              'the project database is deleted. Data that appears in the '
              'dissertation appears only in aggregate, with no individual '
              'identified.'),

          _h('Your choices'),
          _bullets(const [
            'You do not have to take part. You can browse without creating an '
                'account, and you can stop at any time.',
            'You can ask for a copy of what is held about you, or ask for it '
                'to be corrected or deleted, through the Contact page. '
                'Deleting your account removes your personal details; the '
                'browsing records that remain are detached from you and '
                'cannot be traced back.',
            'You can clear the device identifier at any time by clearing this '
                'app\'s storage in your device settings.',
          ]),

          const SizedBox(height: 18),
          Text(
            'This notice is provided in line with the Personal Data '
            'Protection Act 2010 (Malaysia). If you are taking part in the '
            'project\'s test period, this page is also the participant '
            'information sheet for that test.',
            style: TextStyle(
                fontSize: 12.5, height: 1.5, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _h(String text) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.redDark)),
      );

  Widget _p(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13.5, height: 1.55, color: AppTheme.ink)),
      );

  Widget _bullets(List<String> items) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 9),
                      child: Icon(Icons.circle, size: 5, color: AppTheme.red),
                    ),
                    Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: AppTheme.ink)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _callout(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFDE7E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, height: 1.5, color: AppTheme.ink)),
      );
}
