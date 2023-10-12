import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart';

import 'package:fp_bt_printer/fp_bt_printer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(DateTime.now().toString());

    return const MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PrinterDevice> devices = [];
  PrinterDevice? device;
  bool connected = false;

  FpBtPrinter printer = FpBtPrinter();

  Future<void> getDevices() async {
    final response = await printer.scanBondedDevices();
    setState(() {
      devices = response;
    });
  }

  Future<void> setConnect(PrinterDevice d) async {
    final response = await printer.checkConnection(d.address);
    debugPrint(response.message);
    setState(() {
      if (response.success) {
        device = d;
        connected = true;
      } else {
        connected = false;
        device = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('List of devices - Printers'),
      ),
      body: Column(
        children: [
          Column(
            children: [
              TextButton(
                child: const Center(child: Text("Open Settings")),
                onPressed: () => printer.openSettings(),
              )
            ],
          ),
          const Divider(),
          const Text("Search Paired Bluetooth"),
          TextButton(
            onPressed: () {
              getDevices();
            },
            child: const Text("Search"),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Card(
              child: Container(
                padding: const EdgeInsets.all(5),
                height: 200,
                child: ListView.separated(
                  separatorBuilder: (context, index) => const Divider(),
                  itemCount: devices.isNotEmpty ? devices.length : 0,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.print_rounded),
                      onTap: () => setConnect(devices[index]),
                      title: Text(
                        '${devices[index].name} - ${devices[index].address}',
                      ),
                      subtitle: const Text("Click to connect"),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Container(
              color: Colors.grey.shade300,
              child: Column(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.print_rounded,
                        color: connected ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                  ListTile(
                    minVerticalPadding: 5,
                    dense: true,
                    title: connected
                        ? Center(child: Text(device!.name!))
                        : const Center(child: Text("No device")),
                    subtitle: connected
                        ? Center(child: Text(device!.address))
                        : const Center(
                            child: Text("Select a device of the list"),
                          ),
                  ),
                  TextButton(
                    onPressed:
                        connected ? () => printTicket(device!.address) : null,
                    child: const Text("PRINT DATA"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> printTicket(String address) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // //  Print image:
    final ByteData data = await rootBundle.load('assets/wz.png');
    final Uint8List bytesImg = data.buffer.asUint8List();
    var image = decodePng(bytesImg);

    // resize
    var thumbnail =
        copyResize(image!, interpolation: Interpolation.nearest, height: 200);

    bytes += generator.text("fp_bt_printer",
        styles: const PosStyles(align: PosAlign.center, bold: true));

    bytes += generator.imageRaster(thumbnail, align: PosAlign.center);

    bytes += generator.reset();
    bytes += generator.setGlobalCodeTable('CP1252');
    bytes += generator.feed(1);
    bytes += generator.text("HELLO PRINTER by FPV",
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.qrcode("https://github.com/FranciscoPV94",
        size: QRSize.Size6);
    bytes += generator.feed(1);
    bytes += generator.feed(1);

    final resp = await printer.printData(bytes, address: address);

    debugPrint(resp.message);
    debugPrint(address);
  }
}
