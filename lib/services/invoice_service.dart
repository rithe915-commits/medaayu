import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class InvoiceService {
  static final _client = Supabase.instance.client;

  // Generate Professional PDF Payment Receipt matching MedAayu branding
  static Future<Uint8List> generateInvoicePdf({
    required Profile profile,
    required String invoiceNo,
    required String dateStr,
    required String paymentId,
    required String planName,
    required double amount,
    required List<String> benefits,
  }) async {
    final pdf = pw.Document();

    final brandTeal = PdfColor.fromHex('#00B894');
    final brandBlue = PdfColor.fromHex('#3A86F0');
    final darkNavy = PdfColor.fromHex('#1F2937');
    final bgLight = PdfColor.fromHex('#F4F6FA');

    // Load logo image asset
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/logo.jpg');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint("Logo load notice: $e");
    }

    final userEmail = profile.email ?? _client.auth.currentUser?.email ?? 'Hello@medaayu.in';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER ROW WITH LOGO
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 54,
                          height: 54,
                          margin: const pw.EdgeInsets.only(right: 12),
                          child: pw.Image(logoImage),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'MedAayu',
                            style: pw.TextStyle(
                              fontSize: 26,
                              fontWeight: pw.FontWeight.bold,
                              color: brandBlue,
                            ),
                          ),
                          pw.Text(
                            'RIVASA TECHNOLOGIES',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: darkNavy,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text('Email: Hello@medaayu.in', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          pw.Text('Phone: 7620224885 | www.medaayu.in', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: brandTeal,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          'PAID',
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Payment Receipt',
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: darkNavy),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 16),

              // CUSTOMER & INVOICE DETAILS GRID
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CUSTOMER INFORMATION', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(profile.fullName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkNavy)),
                      pw.Text(userEmail, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                      pw.Text('Mobile: +91 ${profile.phone}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE INFORMATION', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text('Invoice #: $invoiceNo', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkNavy)),
                      pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                      pw.Text('Payment ID: $paymentId', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Status: Paid (Google Play)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: brandTeal)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // SUBSCRIPTION DETAILS TABLE
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: bgLight,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                padding: const pw.EdgeInsets.all(12),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Item Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Billing Period', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Unit Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(planName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Monthly', style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('1', style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('INR ${amount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('INR ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // PAYMENT SUMMARY
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text('INR ${amount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('GST (Included):', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text('INR 0.00', style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.Divider(color: PdfColors.grey400),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total Paid:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            pw.Text('INR ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: brandBlue)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // DYNAMIC PLAN BENEFITS SECTION
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('INCLUDED PLAN BENEFITS & FEATURES:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: brandBlue)),
                    pw.SizedBox(height: 6),
                    ...benefits.map(
                      (b) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 3),
                        child: pw.Row(
                          children: [
                            pw.Text('• ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: brandTeal)),
                            pw.Expanded(child: pw.Text(b, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),

              // FOOTER SECTION
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Thank you for choosing MedAayu.',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkNavy),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'This is a computer-generated payment receipt and does not require a signature.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'For any queries, contact: Email: Hello@medaayu.in  |  Phone: 7620224885  |  Website: www.medaayu.in',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  // Upload PDF bytes to Supabase Storage bucket 'invoices' and save DB record
  static Future<void> saveAndUploadInvoice({
    required Profile profile,
    required String invoiceNo,
    required String dateStr,
    required String paymentId,
    required String planName,
    required double amount,
    required List<String> benefits,
  }) async {
    try {
      final pdfBytes = await generateInvoicePdf(
        profile: profile,
        invoiceNo: invoiceNo,
        dateStr: dateStr,
        paymentId: paymentId,
        planName: planName,
        amount: amount,
        benefits: benefits,
      );

      final fileName = '${profile.id}/$invoiceNo.pdf';

      // 1. Upload to Supabase Storage 'invoices' bucket
      try {
        await _client.storage.from('invoices').uploadBinary(
          fileName,
          pdfBytes,
          fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
        );
      } catch (stErr) {
        debugPrint("Storage upload notice: $stErr");
      }

      // 2. Insert record into 'invoices' table
      try {
        await _client.from('invoices').insert({
          'profile_id': profile.id,
          'invoice_no': invoiceNo,
          'amount': amount,
          'plan_name': planName,
          'payment_id': paymentId,
          'file_path': fileName,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (dbErr) {
        debugPrint("Database invoice insert notice: $dbErr");
      }
    } catch (e) {
      debugPrint("Error generating/saving invoice PDF: $e");
    }
  }

  // Download or Preview PDF Invoice cleanly
  static Future<void> downloadInvoice({
    required Profile profile,
    required String invoiceNo,
    required String dateStr,
    required String paymentId,
    required String planName,
    required double amount,
    required List<String> benefits,
  }) async {
    final pdfBytes = await generateInvoicePdf(
      profile: profile,
      invoiceNo: invoiceNo,
      dateStr: dateStr,
      paymentId: paymentId,
      planName: planName,
      amount: amount,
      benefits: benefits,
    );

    await Printing.sharePdf(bytes: pdfBytes, filename: '$invoiceNo.pdf');
  }
}
