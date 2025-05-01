import 'package:flutter/material.dart';

class SettingDialog extends StatefulWidget {
  final double mindb;

  const SettingDialog({super.key, this.mindb = -80});

  @override
  _SettingDialogState createState() => _SettingDialogState();
}

class _SettingDialogState extends State<SettingDialog> {
  double _mindb = 0;

  @override
  void initState() {
    super.initState();
    _mindb = widget.mindb;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Minimum dB: ${_mindb.toStringAsFixed(2)}'),
          Slider(
            value: _mindb,
            min: -80.0,
            max: 0.0,
            divisions: 160,
            label: _mindb.toStringAsFixed(2),
            onChanged: (value) {
              setState(() {
                _mindb = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_mindb);
          },
          child: Text('OK'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
