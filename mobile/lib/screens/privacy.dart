import 'package:flutter/material.dart';
import '../theme.dart';

/// The privacy policy, and the participant information sheet for the test.
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

  static const String lastUpdated = '1 October 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
        children: [
          const Text(
            'Privacy Policy',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.ink),
          ),
          const SizedBox(height: 4),
          Text('Last updated $lastUpdated',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 18),

          _callout(
            'Test period notice. eTech Computer Accessories is being built and '
            'tested as a university final-year project. No order is really '
            'fulfilled, and during the test period you are asked not to send '
            'any money — the bank details shown at checkout are placeholders, '
            'not a real account. If you are taking part in the test, this '
            'policy is also your participant information sheet.',
          ),
          const SizedBox(height: 14),

          _p('eTech Computer Accessories ("eTech", "we", "us") respects your '
              'privacy. This policy explains what personal data we collect '
              'when you use our website and mobile app, why we collect it, who '
              'we share it with, and the choices you have. It is written in '
              'line with the Personal Data Protection Act 2010 (Malaysia). By '
              'using the site or app you agree to the practices described '
              'here.'),

          _h('1. Who we are'),
          _p('eTech Computer Accessories sells computer parts, pre-built PCs, '
              'laptops, peripherals and accessories, and offers PC building '
              'and repair services. This website and app are operated by a '
              'student at a Malaysian university as part of a final-year '
              'project, under the supervision of an academic supervisor. The '
              'operator is responsible for the personal data described in '
              'this policy.'),

          _h('2. Personal data we collect'),
          _rows(const [
            ('Account details',
                'Your name, email address and phone number, and optionally a '
                    'delivery address saved to your profile. Your password is '
                    'held by our authentication provider as a hash — we never '
                    'see or store the password itself.'),
            ('Shopper profile',
                'Whether you shop as a Student, Gamer or Enterprise customer, '
                    'chosen at sign-up and changeable on your profile.'),
            ('Orders',
                'The items you buy (including any colour you pick), the total, '
                    'the name and phone number given at checkout, whether you '
                    'chose collection or delivery, and a delivery address only '
                    'if you chose delivery.'),
            ('Payment receipts',
                'The photo of your bank transfer receipt, if you upload one. '
                    'See section 5.'),
            ('Shopping activity',
                'Products you view, searches you make (and how many results '
                    'came back), items added to your cart or wishlist, and what '
                    'you order. This is recorded whether or not you are signed '
                    'in.'),
            ('AI assistant chats',
                'The questions you ask the shop\'s chatbot and the answers it '
                    'gave.'),
            ('Rig showcase',
                'Photos of a PC you have built, the parts you tag, and your '
                    'first name — only if you choose to submit a build.'),
            ('Device information',
                'A random device identifier used when you browse without '
                    'signing in, and a notification token for this phone, '
                    'removed when you sign out.'),
          ]),
          _sub('Browsing without signing in'),
          _p('If you are not signed in, this device is given a random '
              'identifier (a UUID). It is not linked to your name, email or '
              'any other detail — it only tells us that several visits came '
              'from the same device. If you later sign in or create an '
              'account, the activity recorded under that identifier on this '
              'device is attached to your account, so that a purchase can be '
              'read together with the browsing that led to it. Clearing the '
              'app\'s storage, or uninstalling it, starts a new identifier.'),

          _h('3. How we use your data'),
          _bullets(const [
            'To run your account and orders — keeping your cart and wishlist, '
                'processing orders, arranging collection or delivery, and '
                'showing your order history.',
            'To confirm payments — staff check uploaded receipts against each '
                'order.',
            'To keep you updated — telling you when payment is approved or '
                'rejected, and when an order is ready or has been sent.',
            'To personalise your shopping — the "Picked for you" section on '
                'the home screen is built from your shopper profile, the '
                'products you view, wishlist and buy, and what customers with '
                'similar interests bought. It is shown only to signed-in '
                'customers.',
            'To tell you about relevant offers — see section 4.',
            'To answer your questions — through the AI assistant, WhatsApp, '
                'or the contact form.',
            'To improve the shop — showing staff which products customers are '
                'interested in, and planning stock.',
            'For the final-year project — shopping activity is the dataset '
                'studied in the project\'s dissertation, which asks whether a '
                'shop\'s own records can recommend products and forecast '
                'stock. It appears there only as totals, with no one named.',
          ]),
          _p('We do not sell your personal data, and we do not use it for '
              'third-party advertising.'),

          _h('4. Notifications and offers'),
          _p('If you have an account, we send short messages that appear under '
              'the bell in this app and on the website, and on your phone if '
              'you allow this app to send notifications. There are three '
              'kinds:'),
          _bullets(const [
            'Order updates about your own orders.',
            'Deal alerts — when a product goes on a timed deal, we tell '
                'signed-in customers who saved it to their wishlist, left it '
                'in their cart, or viewed it three or more times. Staff choose '
                'the product; who is told is worked out automatically from '
                'shopping activity.',
            'Weekly picks — at most one message a week, on Saturday morning, '
                'suggesting a product you have been looking at or one picked '
                'for you. The same product is not suggested to you twice '
                'within 30 days.',
          ]),
          _p('For each message we record when it was sent and whether you '
              'opened it, and for offers and picks we look at whether you '
              'viewed or bought that product in the following days. This tells '
              'us whether the messages are useful, and is reported only as '
              'totals.'),
          _p('Opting out: you can turn off notifications for this app in your '
              'phone\'s settings at any time (messages will still wait under '
              'the bell). To stop deal alerts and weekly picks altogether, '
              'tell us through the Contact page on the website.'),

          _h('5. Payments and receipts'),
          _p('We do not take card payments and there is no payment gateway. '
              'Checkout shows bank transfer details and asks you to upload a '
              'photo of the transfer receipt for staff to check. A receipt '
              'usually shows a name, an account or reference number and an '
              'amount, so please treat it like any bank document.'),
          _bullets(const [
            'Receipts are stored privately and can be seen only by you and '
                'shop staff.',
            'They are not used in the project\'s research or dissertation.',
            'You can ask for yours to be deleted at any time.',
            'During the test period there is nothing to pay, so please do not '
                'upload a real bank document.',
          ]),

          _h('6. Who we share it with'),
          _p('We share personal data only with the service providers that run '
              'the shop for us, and only what each one needs:'),
          _rows(const [
            ('Supabase',
                'Database, sign-in and file storage, where all the data above '
                    'is kept.'),
            ('Vercel', 'Hosts the website.'),
            ('Google (Gemini API)',
                'Generates the AI assistant\'s replies. Your message and our '
                    'product catalogue are sent; your name, email and account '
                    'details are not.'),
            ('Google (Firebase Cloud Messaging)',
                'Delivers notifications to this app on your phone.'),
            ('Meta (WhatsApp)',
                'Only if we message you about an order, or you message us.'),
          ]),
          _p('WhatsApp: staff may use the phone number from your order to '
              'message you on WhatsApp about that order, for example to '
              'confirm payment or ask for a clearer receipt. Messages are '
              'written by a person, never sent automatically. Conversations '
              'are handled under WhatsApp\'s privacy policy and stay on their '
              'service after the order is finished. If you prefer, ask us to '
              'use email instead; you never need WhatsApp to buy anything.'),
          _p('Rig showcase: if you submit a build, its photos and your first '
              'name are published on the Rigs screen once staff approve it. '
              'You can ask for it to be removed at any time.'),
          _p('We may also disclose data where the law requires us to.'),

          _h('7. Cookies and local storage'),
          _p('We do not use tracking or advertising cookies, and there are no '
              'third-party analytics trackers. The app\'s own storage keeps '
              'your sign-in session, the device identifier described in '
              'section 2, and small settings.'),

          _h('8. How we protect your data'),
          _p('Data is sent over encrypted connections (HTTPS). Database access '
              'rules mean you can read only your own account and orders; '
              'shopping activity and receipts can be read only by shop staff. '
              'Passwords are stored only as hashes. No system is perfectly '
              'secure, but we take reasonable steps to keep your data safe.'),

          _h('9. How long we keep it'),
          _p('Account and order records are kept for as long as your account '
              'exists. Shopping activity, search and chatbot records are kept '
              'for the length of the project and its assessment, after which '
              'the project database is deleted.'),

          _h('10. Your rights'),
          _p('Under the Personal Data Protection Act 2010 you can:'),
          _bullets(const [
            'Access the personal data we hold about you;',
            'Correct it if it is wrong or out of date (most of it you can edit '
                'yourself on your profile);',
            'Withdraw consent and ask us to delete it — deleting your account '
                'removes your personal details, and any shopping records left '
                'behind are detached from you and cannot be traced back;',
            'Limit marketing by opting out of deal alerts and weekly picks.',
          ]),
          _p('Taking part is voluntary: you can browse without an account and '
              'stop at any time. To clear the device identifier, clear this '
              'app\'s storage in your device settings.'),

          _h('11. Changes to this policy'),
          _p('We may update this policy when the shop changes what it collects '
              'or how it uses it. The date at the top shows when it was last '
              'changed.'),

          _h('12. Contact us'),
          _p('For any question about this policy, or to make a request about '
              'your data, please use the Contact page on our website.'),
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

  Widget _sub(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.ink)),
      );

  Widget _p(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13.5, height: 1.55, color: AppTheme.ink)),
      );

  /// The website's two-column tables, stacked as label over text.
  Widget _rows(List<(String, String)> rows) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rows[i].$1,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.ink)),
                    const SizedBox(height: 3),
                    Text(rows[i].$2,
                        style: const TextStyle(
                            fontSize: 13, height: 1.5, color: AppTheme.ink)),
                  ],
                ),
              ),
          ],
        ),
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
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, height: 1.5, color: AppTheme.ink)),
      );
}
