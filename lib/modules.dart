import 'package:flutter/material.dart';

enum FType { text, multiline, date, email, phone }

class Fld {
  const Fld(this.key, this.label, [this.type = FType.text, this.required = false]);
  final String key, label;
  final FType type;
  final bool required;
}

class RowAction {
  const RowAction(this.label, this.method, this.path, [this.body = const <String, dynamic>{}]);
  final String label, method, path; // path may contain {id}
  final Map<String, dynamic> body;
}

class Module {
  const Module(this.key, this.title, this.icon,
      {this.path,
      this.custom,
      this.mine = false,
      this.titleKeys = const [],
      this.subKeys = const [],
      this.trailKeys = const [],
      this.actions = const [],
      this.fields = const []});
  final String key, title; // key = permission module key from the API matrix
  final IconData icon;
  final String? path, custom;
  final bool mine; // scope list to the signed-in employee
  final List<String> titleKeys, subKeys, trailKeys;
  final List<RowAction> actions;
  final List<Fld> fields;
}

const _approve = [
  RowAction('Approve', 'PUT', '/leaves/{id}', {'status': 'Approved'}),
  RowAction('Reject', 'PUT', '/leaves/{id}', {'status': 'Rejected'}),
];

/// Home-screen modules. Hidden automatically when the permission matrix says NONE.
const kModules = <Module>[
  Module('employee-portal', 'Employee Portal', Icons.badge_outlined, custom: 'portal'),
  Module('dashboard', 'Dashboard', Icons.space_dashboard_outlined, custom: 'dashboard'),
  Module('opportunities', 'Opportunities', Icons.trending_up, path: '/opportunities',
      titleKeys: ['title', 'name', 'dealName'], subKeys: ['clientName', 'stage'],
      trailKeys: ['expectedRevenue', 'value']),
  Module('clients', 'Clients', Icons.business_outlined, path: '/clients',
      titleKeys: ['companyName', 'name'], subKeys: ['phone', 'email', 'gstin'],
      fields: [
        Fld('companyName', 'Company name', FType.text, true),
        Fld('gstin', 'GSTIN'),
        Fld('pan', 'PAN'),
        Fld('billingAddress', 'Billing address', FType.multiline),
        Fld('email', 'Email', FType.email),
        Fld('phone', 'Phone', FType.phone),
      ]),
  Module('products', 'Products', Icons.inventory_2_outlined, path: '/products',
      titleKeys: ['name'], subKeys: ['sku', 'category', 'stock'], trailKeys: ['sellingPrice', 'price']),
  Module('quotations', 'Quotations', Icons.request_quote_outlined, path: '/quotations',
      titleKeys: ['quoteNumber', 'quotationNumber', 'number'], subKeys: ['clientName', 'status'],
      trailKeys: ['grandTotal', 'total']),
  Module('invoices', 'Invoices', Icons.receipt_long_outlined, path: '/invoices',
      titleKeys: ['invoiceNumber', 'number'], subKeys: ['clientName', 'status'],
      trailKeys: ['grandTotal', 'total']),
  Module('payments', 'Payments', Icons.payments_outlined, path: '/payments',
      titleKeys: ['receiptNumber', 'invoiceNumber', 'id'], subKeys: ['clientName', 'date', 'mode'],
      trailKeys: ['amount']),
  Module('expenses', 'Expenses', Icons.account_balance_wallet_outlined, path: '/daily-expenses',
      titleKeys: ['title', 'description', 'category'], subKeys: ['date', 'paymentMode'],
      trailKeys: ['amount']),
  Module('purchase-requests', 'Purchase Requests', Icons.shopping_cart_outlined,
      path: '/purchase-requests', titleKeys: ['title', 'itemName', 'id'], subKeys: ['requestedBy', 'status'],
      actions: [
        RowAction('Approve', 'PUT', '/purchase-requests/{id}', {'status': 'Approved'}),
        RowAction('Reject', 'PUT', '/purchase-requests/{id}', {'status': 'Rejected'}),
      ]),
  Module('employees', 'Employees', Icons.groups_outlined, path: '/employees',
      titleKeys: ['name', 'fullName'], subKeys: ['employeeId', 'designation', 'department']),
  Module('attendance', 'Leave Requests', Icons.event_available_outlined, path: '/leaves',
      titleKeys: ['employeeName', 'employeeId'], subKeys: ['leaveType', 'startDate', 'endDate'],
      trailKeys: ['status'], actions: _approve),
  Module('payroll', 'Payroll', Icons.request_page_outlined, path: '/payroll',
      titleKeys: ['employeeName', 'name'], subKeys: ['month', 'year', 'status'],
      trailKeys: ['netPay', 'takeHome']),
  Module('letterpad', 'Letters', Icons.mail_outline, path: '/letters',
      titleKeys: ['subject', 'referenceNumber'], subKeys: ['date', 'status']),
  Module('audit', 'Audit Logs', Icons.shield_outlined, path: '/audit-logs',
      titleKeys: ['action'], subKeys: ['userName', 'timestamp']),
];

/// Sub-screens of the Employee Portal (scoped to the signed-in employee).
const kPortalModules = <Module>[
  Module('employee-portal', 'My Attendance', Icons.calendar_month_outlined, path: '/attendance', mine: true,
      titleKeys: ['date'], subKeys: ['checkIn', 'checkOut', 'status'], trailKeys: ['workingHours']),
  Module('employee-portal', 'My Leaves', Icons.beach_access_outlined, path: '/leaves', mine: true,
      titleKeys: ['leaveType', 'type'], subKeys: ['startDate', 'endDate'], trailKeys: ['status'],
      fields: [
        Fld('leaveType', 'Leave type', FType.text, true),
        Fld('startDate', 'From', FType.date, true),
        Fld('endDate', 'To', FType.date, true),
        Fld('reason', 'Reason', FType.multiline),
      ]),
  Module('employee-portal', 'My Payslips', Icons.description_outlined, path: '/payroll', mine: true,
      titleKeys: ['month', 'id'], subKeys: ['year', 'status'], trailKeys: ['netPay', 'takeHome']),
  Module('employee-portal', 'Salary Advances', Icons.savings_outlined, path: '/salary-advances', mine: true,
      titleKeys: ['reason', 'id'], subKeys: ['date', 'status'], trailKeys: ['amount']),
  Module('employee-portal', 'Bonuses', Icons.card_giftcard_outlined, path: '/salary-bonuses', mine: true,
      titleKeys: ['type', 'reason', 'id'], subKeys: ['date', 'status'], trailKeys: ['amount']),
  Module('employee-portal', 'Holidays', Icons.celebration_outlined, path: '/holidays',
      titleKeys: ['name', 'title'], subKeys: ['date', 'type']),
];
