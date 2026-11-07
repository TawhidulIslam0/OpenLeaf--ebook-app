import 'package:flutter/material.dart';
import 'package:flutter_ebook_app/src/common/common.dart';

class MyErrorWidget extends StatelessWidget {
  final VoidCallback refreshCallBack;
  final bool isConnection;
  final String? message;

  const MyErrorWidget({
    super.key,
    required this.refreshCallBack,
    this.isConnection = false,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight.isFinite && constraints.maxHeight < 280;
        return Container(
          alignment: Alignment.center,
          margin: EdgeInsets.symmetric(horizontal: compact ? 12.0 : 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '😔',
                style: TextStyle(fontSize: compact ? 40.0 : 60.0),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: compact ? 6.0 : 15.0),
                child: Text(
                  message ?? getErrorText(),
                  textAlign: TextAlign.center,
                  maxLines: compact ? 3 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    color: context.theme.textTheme.titleLarge!.color,
                    fontSize: compact ? 14.0 : 17.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: refreshCallBack,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(0, compact ? 34.0 : 48.0),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12.0 : 16.0,
                    vertical: compact ? 4.0 : 8.0,
                  ),
                  tapTargetSize: compact
                      ? MaterialTapTargetSize.shrinkWrap
                      : MaterialTapTargetSize.padded,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  backgroundColor: context.theme.colorScheme.secondary,
                ),
                child: Text(
                  'TRY AGAIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 12.0 : 15.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String getErrorText() {
    if (isConnection) {
      return 'There is a problem with your internet connection. '
          '\nPlease try again.';
    } else {
      return 'Could not load this page. \nPlease try again.';
    }
  }
}
