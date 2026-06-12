
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DebtLedgerApp());
}

class DebtLedgerApp extends StatelessWidget {
  const DebtLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دفتر الديون',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B78D0)),
        scaffoldBackgroundColor: const Color(0xFFF4FAFF),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(),
      ),
    );
  }
}

enum EntryType { debt, payment }

class Customer {
  final String id;
  String name;
  String phone;
  String note;
  final int createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'note': note,
        'createdAt': createdAt,
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        phone: json['phone'] ?? '',
        note: json['note'] ?? '',
        createdAt: json['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      );
}

class LedgerEntry {
  final String id;
  final String customerId;
  final EntryType type;
  final double amount;
  final String details;
  final int date;

  LedgerEntry({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.details,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'type': type.name,
        'amount': amount,
        'details': details,
        'date': date,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: json['id'] ?? '',
        customerId: json['customerId'] ?? '',
        type: json['type'] == 'payment' ? EntryType.payment : EntryType.debt,
        amount: (json['amount'] ?? 0).toDouble(),
        details: json['details'] ?? '',
        date: json['date'] ?? DateTime.now().millisecondsSinceEpoch,
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum HomeTab { customers, report }

class _HomeScreenState extends State<HomeScreen> {
  List<Customer> customers = [];
  List<LedgerEntry> entries = [];
  String query = '';
  HomeTab tab = HomeTab.customers;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  String newId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final customersRaw = prefs.getString('customers_v1');
      final entriesRaw = prefs.getString('entries_v1');

      if (customersRaw != null) {
        customers = (jsonDecode(customersRaw) as List)
            .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (entriesRaw != null) {
        entries = (jsonDecode(entriesRaw) as List)
            .map((e) => LedgerEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      setState(() {});
    } catch (_) {}
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'customers_v1',
      jsonEncode(customers.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'entries_v1',
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  double customerDebt(String id) {
    return entries
        .where((e) => e.customerId == id && e.type == EntryType.debt)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double customerPayment(String id) {
    return entries
        .where((e) => e.customerId == id && e.type == EntryType.payment)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double customerBalance(String id) {
    return customerDebt(id) - customerPayment(id);
  }

  double totalDebt() {
    return entries
        .where((e) => e.type == EntryType.debt)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double totalPayment() {
    return entries
        .where((e) => e.type == EntryType.payment)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double totalBalance() => totalDebt() - totalPayment();

  List<Customer> filteredCustomers() {
    final list = [...customers];
    list.sort((a, b) => customerBalance(b.id).compareTo(customerBalance(a.id)));
    final q = query.trim();
    if (q.isEmpty) return list;
    return list
        .where((c) => c.name.contains(q) || c.phone.contains(q) || c.note.contains(q))
        .toList();
  }

  String money(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  String dateText(int timestamp) {
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  void snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> addCustomerDialog() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة عميل / مدين'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                input(name, 'اسم العميل', Icons.person),
                const SizedBox(height: 10),
                input(phone, 'رقم الهاتف', Icons.phone, keyboard: TextInputType.phone),
                const SizedBox(height: 10),
                input(note, 'ملاحظة اختيارية', Icons.note_alt),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  snack('اكتب اسم العميل');
                  return;
                }
                customers.add(Customer(
                  id: newId(),
                  name: name.text.trim(),
                  phone: phone.text.trim(),
                  note: note.text.trim(),
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                ));
                await saveData();
                if (!mounted) return;
                Navigator.pop(context);
                setState(() {});
                snack('تمت إضافة العميل');
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> editCustomerDialog(Customer c) async {
    final name = TextEditingController(text: c.name);
    final phone = TextEditingController(text: c.phone);
    final note = TextEditingController(text: c.note);

    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل العميل'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                input(name, 'اسم العميل', Icons.person),
                const SizedBox(height: 10),
                input(phone, 'رقم الهاتف', Icons.phone, keyboard: TextInputType.phone),
                const SizedBox(height: 10),
                input(note, 'ملاحظة اختيارية', Icons.note_alt),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  snack('اكتب اسم العميل');
                  return;
                }
                c.name = name.text.trim();
                c.phone = phone.text.trim();
                c.note = note.text.trim();
                await saveData();
                if (!mounted) return;
                Navigator.pop(context);
                setState(() {});
                snack('تم التعديل');
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> addEntryDialog(Customer c, EntryType type) async {
    final amount = TextEditingController();
    final details = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(type == EntryType.debt ? 'تسجيل دين' : 'تسجيل تسديد'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: softBox(16),
                  child: Text(
                    c.name,
                    style: const TextStyle(
                      color: Color(0xFF063B63),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                input(
                  amount,
                  'المبلغ',
                  Icons.payments,
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                input(details, type == EntryType.debt ? 'تفاصيل الدين' : 'تفاصيل التسديد', Icons.description),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final text = amount.text.trim().replaceAll(',', '.');
                final value = double.tryParse(text);
                if (value == null || value <= 0) {
                  snack('اكتب مبلغًا صحيحًا');
                  return;
                }
                entries.add(LedgerEntry(
                  id: newId(),
                  customerId: c.id,
                  type: type,
                  amount: value,
                  details: details.text.trim(),
                  date: DateTime.now().millisecondsSinceEpoch,
                ));
                await saveData();
                if (!mounted) return;
                Navigator.pop(context);
                setState(() {});
                snack(type == EntryType.debt ? 'تم تسجيل الدين' : 'تم تسجيل التسديد');
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD90429)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Future<void> deleteCustomer(Customer c) async {
    final ok = await confirm('حذف العميل؟', 'سيتم حذف العميل وجميع حركاته.');
    if (!ok) return;
    customers.removeWhere((x) => x.id == c.id);
    entries.removeWhere((e) => e.customerId == c.id);
    await saveData();
    setState(() {});
    snack('تم حذف العميل');
  }

  Future<void> deleteEntry(LedgerEntry e) async {
    final ok = await confirm('حذف الحركة؟', 'هل تريد حذف هذه الحركة؟');
    if (!ok) return;
    entries.removeWhere((x) => x.id == e.id);
    await saveData();
    setState(() {});
    snack('تم حذف الحركة');
  }

  TextField input(TextEditingController controller, String label, IconData icon, {TextInputType? keyboard}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: tab == HomeTab.customers
          ? FloatingActionButton.extended(
              onPressed: addCustomerDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('إضافة عميل'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            header(),
            tabs(),
            Expanded(
              child: tab == HomeTab.customers ? customersPage() : reportPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget header() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(15),
      decoration: card(26),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF00A8FF), Color(0xFF0066FF)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 29),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'دفتر الديون',
                      style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Color(0xFF063B63)),
                    ),
                    Text(
                      'إدارة الديون والتسديدات بدون إنترنت',
                      style: TextStyle(color: Color(0xFF6B8198), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: summaryMini('الديون', money(totalDebt()), const Color(0xFFE63946), Icons.trending_up)),
              const SizedBox(width: 8),
              Expanded(child: summaryMini('التسديد', money(totalPayment()), const Color(0xFF00A96B), Icons.done_all)),
              const SizedBox(width: 8),
              Expanded(child: summaryMini('الرصيد', money(totalBalance()), const Color(0xFF0077FF), Icons.calculate)),
            ],
          ),
        ],
      ),
    );
  }

  Widget summaryMini(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: softBox(18),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF6B8198), fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget tabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: softBox(18),
        child: Row(
          children: [
            tabButton('العملاء', HomeTab.customers, Icons.people_alt),
            tabButton('التقرير', HomeTab.report, Icons.bar_chart),
          ],
        ),
      ),
    );
  }

  Widget tabButton(String text, HomeTab value, IconData icon) {
    final active = tab == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => setState(() => tab = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0077FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: active ? Colors.white : const Color(0xFF50677E)),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF50677E),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget customersPage() {
    final list = filteredCustomers();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              hintText: 'بحث باسم العميل أو الهاتف',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? empty('لا يوجد عملاء بعد.\nاضغط إضافة عميل للبدء.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                  itemCount: list.length,
                  itemBuilder: (_, i) => customerCard(list[i]),
                ),
        ),
      ],
    );
  }

  Widget customerCard(Customer c) {
    final debt = customerDebt(c.id);
    final pay = customerPayment(c.id);
    final bal = debt - pay;
    final color = bal > 0 ? const Color(0xFFE63946) : const Color(0xFF00A96B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: card(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Directionality(
                textDirection: TextDirection.rtl,
                child: CustomerScreen(
                  customer: c,
                  entries: entries.where((e) => e.customerId == c.id).toList(),
                  money: money,
                  dateText: dateText,
                  onAddDebt: () => addEntryDialog(c, EntryType.debt),
                  onAddPayment: () => addEntryDialog(c, EntryType.payment),
                  onDeleteEntry: deleteEntry,
                ),
              ),
            ),
          );
          setState(() {});
        },
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE8F8FF),
                  child: Text(c.name.isEmpty ? '؟' : c.name.characters.first, style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF063B63))),
                      if (c.phone.isNotEmpty)
                        Text(c.phone, style: const TextStyle(color: Color(0xFF6B8198), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') editCustomerDialog(c);
                    if (v == 'delete') deleteCustomer(c);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(value: 'delete', child: Text('حذف')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: pill('دين', money(debt), const Color(0xFFE63946))),
                const SizedBox(width: 7),
                Expanded(child: pill('تسديد', money(pay), const Color(0xFF00A96B))),
                const SizedBox(width: 7),
                Expanded(child: pill('رصيد', money(bal), color)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => addEntryDialog(c, EntryType.debt),
                    icon: const Icon(Icons.add),
                    label: const Text('دين'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => addEntryDialog(c, EntryType.payment),
                    icon: const Icon(Icons.check),
                    label: const Text('تسديد'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget pill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      decoration: softBox(16),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B8198), fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(height: 3),
          FittedBox(child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 17))),
        ],
      ),
    );
  }

  Widget reportPage() {
    final activeCustomers = customers.where((c) => customerBalance(c.id) > 0).length;
    final paidCustomers = customers.where((c) => customerBalance(c.id) <= 0 && (customerDebt(c.id) > 0 || customerPayment(c.id) > 0)).length;
    final biggest = customers.isEmpty
        ? null
        : customers.reduce((a, b) => customerBalance(a.id) >= customerBalance(b.id) ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
      children: [
        reportCard('عدد العملاء', customers.length.toString(), Icons.people_alt, const Color(0xFF0077FF)),
        reportCard('عملاء عليهم رصيد', activeCustomers.toString(), Icons.warning_amber, const Color(0xFFE63946)),
        reportCard('عملاء مسددين', paidCustomers.toString(), Icons.verified, const Color(0xFF00A96B)),
        reportCard('عدد الحركات', entries.length.toString(), Icons.receipt_long, const Color(0xFF7B61FF)),
        if (biggest != null)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(top: 10),
            decoration: card(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('أكبر رصيد مستحق', style: TextStyle(color: Color(0xFF6B8198), fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(biggest.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF063B63))),
                const SizedBox(height: 4),
                Text('${money(customerBalance(biggest.id))} دينار', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFFE63946))),
              ],
            ),
          ),
      ],
    );
  }

  Widget reportCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: card(22),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF063B63), fontWeight: FontWeight.w900, fontSize: 16))),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 24)),
        ],
      ),
    );
  }

  Widget empty(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF6B8198), fontWeight: FontWeight.w800, height: 1.8),
        ),
      ),
    );
  }

  BoxDecoration card(double radius) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFDCEEFA)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0069AA).withOpacity(.08),
          blurRadius: 24,
          offset: const Offset(0, 10),
        )
      ],
    );
  }

  BoxDecoration softBox(double radius) {
    return BoxDecoration(
      color: const Color(0xFFF7FCFF),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFDCEEFA)),
    );
  }
}

class CustomerScreen extends StatefulWidget {
  final Customer customer;
  final List<LedgerEntry> entries;
  final String Function(double) money;
  final String Function(int) dateText;
  final Future<void> Function() onAddDebt;
  final Future<void> Function() onAddPayment;
  final Future<void> Function(LedgerEntry) onDeleteEntry;

  const CustomerScreen({
    super.key,
    required this.customer,
    required this.entries,
    required this.money,
    required this.dateText,
    required this.onAddDebt,
    required this.onAddPayment,
    required this.onDeleteEntry,
  });

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  double debt() => widget.entries.where((e) => e.type == EntryType.debt).fold(0, (a, e) => a + e.amount);
  double payment() => widget.entries.where((e) => e.type == EntryType.payment).fold(0, (a, e) => a + e.amount);
  double balance() => debt() - payment();

  @override
  Widget build(BuildContext context) {
    final list = [...widget.entries]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAFF),
      appBar: AppBar(
        title: Text(widget.customer.name),
        centerTitle: true,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await widget.onAddDebt();
                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('دين'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    await widget.onAddPayment();
                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('تسديد'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: card(24),
            child: Column(
              children: [
                if (widget.customer.phone.isNotEmpty)
                  Text(widget.customer.phone, style: const TextStyle(color: Color(0xFF6B8198), fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: mini('دين', widget.money(debt()), const Color(0xFFE63946))),
                    const SizedBox(width: 8),
                    Expanded(child: mini('تسديد', widget.money(payment()), const Color(0xFF00A96B))),
                    const SizedBox(width: 8),
                    Expanded(child: mini('رصيد', widget.money(balance()), const Color(0xFF0077FF))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('كشف الحساب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: Color(0xFF063B63))),
          const SizedBox(height: 8),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(22),
              child: Text(
                'لا توجد حركات لهذا العميل.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B8198), fontWeight: FontWeight.w800),
              ),
            )
          else
            ...list.map(entryCard),
        ],
      ),
    );
  }

  Widget mini(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: softBox(16),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B8198), fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18))),
        ],
      ),
    );
  }

  Widget entryCard(LedgerEntry e) {
    final isDebt = e.type == EntryType.debt;
    final color = isDebt ? const Color(0xFFE63946) : const Color(0xFF00A96B);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: card(20),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(.12),
            child: Icon(isDebt ? Icons.trending_up : Icons.done_all, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isDebt ? 'دين' : 'تسديد', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
                Text(widget.dateText(e.date), style: const TextStyle(color: Color(0xFF6B8198), fontWeight: FontWeight.w700, fontSize: 12)),
                if (e.details.isNotEmpty)
                  Text(e.details, style: const TextStyle(color: Color(0xFF102033), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(widget.money(e.amount), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 19)),
              IconButton(
                onPressed: () async {
                  await widget.onDeleteEntry(e);
                  if (mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline),
                color: const Color(0xFFD90429),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration card(double radius) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFDCEEFA)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0069AA).withOpacity(.08),
          blurRadius: 22,
          offset: const Offset(0, 9),
        )
      ],
    );
  }

  BoxDecoration softBox(double radius) {
    return BoxDecoration(
      color: const Color(0xFFF7FCFF),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFDCEEFA)),
    );
  }
}
