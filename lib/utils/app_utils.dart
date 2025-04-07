import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';

String? prevMessage;

void showToast(
    BuildContext context, String message, dynamic activeToast, bool isError) {
  if (prevMessage == message) {
    return;
  }
  activeToast = toastification.show(
      context: context,
      type: isError == true
          ? ToastificationType.error
          : ToastificationType.success,
      title: Text(message),
      alignment: Alignment.topCenter,
      foregroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
      autoCloseDuration: const Duration(seconds: 5),
      showProgressBar: false,
      style: ToastificationStyle.minimal,
      callbacks: ToastificationCallbacks(onCloseButtonTap: (value) {
        toastification.dismiss(activeToast);
        prevMessage = null;
      }));
  prevMessage = message;
  Future.delayed(const Duration(seconds: 5), () {
    prevMessage = null;
  });
}

void launchDialer(String phoneNumber, BuildContext context) async {
  final uri = Uri(scheme: 'tel', path: phoneNumber);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    showToast(
      context,
      'Could not launch dialer',
      null,
      true,
    );
  }
}