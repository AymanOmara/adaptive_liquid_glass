import 'package:flutter/widgets.dart';

/// The Material app bar's title with a [subtitle] stacked under it.
Widget? materialTitle(Widget? title, Widget? subtitle) =>
    title == null || subtitle == null
    ? title
    : Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            child: subtitle,
          ),
        ],
      );
