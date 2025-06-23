import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: NFCReaderScreen());
  }
}

// This simple code you can simply implement NFC in Flutter to transfer peer-to-peer data using the nfc_manager package.

class NFCReaderScreen extends StatefulWidget {
  const NFCReaderScreen({super.key});

  @override
  State<NFCReaderScreen> createState() => _NFCReaderScreenState();
}

class _NFCReaderScreenState extends State<NFCReaderScreen> {
  String? nfcData = "Tap an NFC tag";

  /// This method creates a proper NDEF Text Record for version ^4.0.2
  /// Create a proper NDEF Text Record using the new constructor format
  NdefRecord createTextNdefRecord(String text, {String languageCode = 'en'}) {
    final languageCodeBytes = utf8.encode(languageCode);
    final textBytes = utf8.encode(text);

    // Payload: status byte + language code + text
    final payload = Uint8List(1 + languageCodeBytes.length + textBytes.length);
    payload[0] = languageCodeBytes.length;
    payload.setRange(1, 1 + languageCodeBytes.length, languageCodeBytes);
    payload.setRange(1 + languageCodeBytes.length, payload.length, textBytes);

    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown, // NFC Forum Well-Known Type
      type: Uint8List.fromList([0x54]), // 0x54 = 'T' for Text
      identifier: Uint8List(0), // Empty identifier
      payload: payload,
    );
  }

  Future<void> startNFC() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      setState(() {
        nfcData = "NFC is not available on this device";
      });
      return;
    }
    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      // Provide required polling options
      onDiscovered: onDiscoverNdef,
      alertMessageIos: 'Scan your NFC tag',
    );
  }
  // Step 4: Implement NFC Writing
  // Apart from reading, you can also write data to an NFC tag. Below is an example:

  Future<void> writeNFC(String message) async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      return;
    }

    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (NfcTag tag) async {
        Ndef? ndef = Ndef.from(tag);
        if (ndef != null && ndef.isWritable) {
          // Create your NDEF message with the text record.
          NdefMessage ndefMessage = NdefMessage(
            records: [createTextNdefRecord("Hello NFC")],
          );
          await ndef.write(message: ndefMessage);
        }
        NfcManager.instance.stopSession();
      },
    );
  }

  void onDiscoverNdef(NfcTag tag) async {
    try {
      print("we are here");
      // Process NFC tag, When an NFC tag is discovered, print its data to the console.
      log('NFC Tag Detected: ${tag.toString()}');

      if (tag == null) {
        return;
      }
      // Check if the tag supports NDEF (NFC Data Exchange Format)
      final ndef = Ndef.from(tag);
      nfcData = ndef?.toString();

      if (ndef == null) {
        debugPrint('Tag is not NDEF-compatible');
        return;
      }

      // Read NDEF message
      final message = await ndef.read();
      nfcData = message?.toString() ?? 'No NDEF message found on tag';

      if (message == null) {
        debugPrint('No NDEF message found on tag');
        return;
      }

      // Extract records (text, URLs, etc.)
      for (final record in message.records) {
        debugPrint('NDEF Record: ${record.type} - ${record.payload}');
        setState(() {
          nfcData = 'Type: ${record.type}, Payload: ${record.payload}';
        });
      }

      await NfcManager.instance.stopSession();
    } catch (e) {
      debugPrint('Error reading NFC tag: $e');
    } finally {
      await NfcManager.instance.stopSession();
    }
    await NfcManager.instance.stopSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("NFC Reader")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(nfcData ?? "Can't parse data", style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            ElevatedButton(onPressed: startNFC, child: Text("Scan NFC Tag")),
            ElevatedButton(
              onPressed: () => writeNFC("Hello from Flutter!"),
              child: Text("Write to NFC Tag"),
            ),
          ],
        ),
      ),
    );
  }
}

// void onDiscoverMifareClassic(NfcTag tag) async {
//   try {
//     final mifare = MifareClassic.from(tag);
//     if (mifare == null) {
//       debugPrint('Tag is not Mifare Classic');
//       return;
//     }

//     await mifare.connect();
//     // Read block 4 (example)
//     final data = await mifare.readBlock(4);
//     debugPrint('Mifare Data: $data');
//     setState(() {
//       nfcData = 'Block 4: $data';
//     });
//   } catch (e) {
//     debugPrint('Error reading Mifare tag: $e');
//   } finally {
//     await NfcManager.instance.stopSession();
//   }
// }

// void onDiscoverIsoDep(NfcTag tag) async {
//   try {
//     final isoDep = IsoDep.from(tag);
//     if (isoDep == null) {
//       debugPrint('Tag is not ISO-DEP compatible');
//       return;
//     }

//     await isoDep.connect();
//     // Send APDU commands (e.g., for EMV cards)
//     final response = await isoDep.transmit(
//       Uint8List.fromList([0x00, 0xA4, 0x04, 0x00]),
//     );
//     debugPrint('ISO-DEP Response: $response');
//     setState(() {
//       nfcData = 'Response: $response';
//     });
//   } catch (e) {
//     debugPrint('Error reading ISO-DEP tag: $e');
//   } finally {
//     await NfcManager.instance.stopSession();
//   }
// }
