import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../api.dart' as api;

class PayPalService {
  // PayPal Client ID (same as website - sandbox)
  static const String PAYPAL_CLIENT_ID = 'AZwIftz_uEFyQ-OCopoy7MXW8pk-JKgH4IeLTKkpDXF3GjnpeSQ4am5NZxFeT4spij_sgxIv8DETjzux';

  // Show PayPal payment dialog
  static Future<Map<String, dynamic>?> showPayPalPayment({
    required BuildContext context,
    required int reservationId,
    required int propertyId,
    required double amount,
    required String currency,
    required String propertyName,
    required String checkIn,
    required String checkOut,
    required bool isInstantPayment,
  }) async {
    try {
      // First, check if the property owner has a PayPal email set
      String? ownerPayPalEmail;
      try {
        final ownerPayPal = await api.getPropertyOwnerPayPalId(propertyId);
        ownerPayPalEmail = ownerPayPal['payPalId'] as String?;

        if (ownerPayPalEmail == null || ownerPayPalEmail.isEmpty || ownerPayPalEmail == 'null') {
          throw Exception(
            'PayPal payment unavailable: The property owner has not set up their PayPal email. '
            'Please contact the property owner to add their PayPal email in their profile settings.'
          );
      }
        print('PayPal Service: Owner PayPal email verified: ${ownerPayPalEmail.isNotEmpty ? "Set" : "Not set"}');
      } catch (e) {
        // If the error is about missing PayPal email, rethrow it
        if (e.toString().contains('PayPal payment unavailable') || 
            e.toString().contains('not set up their PayPal')) {
          rethrow;
        }
        // If API endpoint fails, log but continue - backend will validate
        print('PayPal Service: Warning - Could not verify owner PayPal email: $e');
        print('PayPal Service: Continuing with order creation - backend will validate');
      }

      // Show WebView with PayPal SDK (client-side, like website)
      if (!context.mounted) return null;
      
      return await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => _PayPalPaymentDialog(
            reservationId: reservationId,
            propertyId: propertyId,
            amount: amount,
            currency: currency,
            propertyName: propertyName,
            checkIn: checkIn,
            checkOut: checkOut,
            ownerPayPalEmail: ownerPayPalEmail ?? '',
            isInstantPayment: isInstantPayment,
          ),
        ),
      );
    } catch (error) {
      print('PayPal payment error: $error');
      rethrow;
    }
  }

  // Generate HTML page with PayPal SDK (similar to website)
  static String _generatePayPalHTML({
    required double amount,
    required String currency,
    required String propertyName,
    required String reservationId,
    required String ownerPayPalEmail,
  }) {
    final paypalAmount = amount.toStringAsFixed(2);

    // Escape strings for JavaScript
    String escapeJS(String str) {
      return str
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"')
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r');
    }

    final escapedPropertyName = escapeJS(propertyName);
    final escapedReservationId = escapeJS(reservationId);
    final escapedOwnerEmail = escapeJS(ownerPayPalEmail);

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script>
    // Set proper origin for postMessage
    if (window.location.protocol === 'about:' || window.location.href === 'about:blank') {
      // This will be fixed by baseUrl, but just in case
      console.log('WebView origin detected, baseUrl should fix this');
    }
    
    // Suppress PayPal SDK warnings for WebView (non-critical)
    window.addEventListener('error', function(e) {
      if (e.message && (
        e.message.includes('Global messaging not needed') ||
        e.message.includes('postMessage')
      )) {
        // Only suppress if it's a known WebView issue
        console.warn('PayPal SDK WebView warning:', e.message);
        // Don't prevent default - let it try to work
      }
    }, true);
    
    // Catch unhandled promise rejections
    window.addEventListener('unhandledrejection', function(e) {
      if (e.reason && e.reason.message && (
        e.reason.message.includes('Global messaging not needed') ||
        e.reason.message.includes('postMessage')
      )) {
        console.warn('PayPal SDK promise rejection (may be non-critical):', e.reason.message);
        // Don't prevent - let PayPal SDK handle it
      }
    });
  </script>
  <script src="https://www.paypal.com/sdk/js?client-id=$PAYPAL_CLIENT_ID&currency=$currency&intent=capture&components=buttons&disable-funding=credit,card" 
          onerror="console.error('Failed to load PayPal SDK script'); document.getElementById('error-message').innerHTML='<div class=\\'error\\'>Failed to load PayPal SDK. Please check your internet connection.</div>';"></script>
  <style>
    body {
      margin: 0;
      padding: 0;
      font-family: Arial, sans-serif;
      background: #ffffff;
    }
    .payment-container {
      width: 100%;
      min-height: 100vh;
      margin: 0;
      background: white;
      padding: 18px;
      box-sizing: border-box;
    }
    .payment-details {
      margin-bottom: 20px;
      padding: 15px;
      background: #f8f9fa;
      border-radius: 4px;
    }
    .payment-details h3 {
      margin: 0 0 10px 0;
      color: #333;
    }
    .payment-details p {
      margin: 5px 0;
      color: #666;
    }
    .amount {
      font-size: 24px;
      font-weight: bold;
      color: #0070ba;
      margin: 10px 0;
    }
    #paypal-button-container {
      margin-top: 20px;
    }
    .error {
      color: red;
      padding: 10px;
      background: #ffe6e6;
      border-radius: 4px;
      margin-bottom: 20px;
    }
  </style>
</head>
<body>
  <div class="payment-container">
    <div class="payment-details">
      <h3>$escapedPropertyName</h3>
      <p>Reservation ID: #$escapedReservationId</p>
      <div class="amount">$currency ${amount.toStringAsFixed(2)}</div>
    </div>
    <div id="loading-message" style="padding: 20px; text-align: center; color: #666;">
      Loading PayPal...
    </div>
    <div id="paypal-button-container"></div>
    <div id="error-message"></div>
  </div>

  <script>
    console.log('=== PayPal Payment Page Loaded ===');
    console.log('Page URL:', window.location.href);
    console.log('Document ready state:', document.readyState);
    
    let orderId = null;
    let paypalLoaded = false;
    
    // Test function to verify JavaScript is working
    function testJavaScript() {
      console.log('JavaScript is working!');
      const container = document.getElementById('paypal-button-container');
      if (container) {
        console.log('Button container found');
      } else {
        console.error('Button container NOT found!');
      }
      return true;
    }
    
    // Run test immediately
    testJavaScript();

    // Wait for PayPal SDK to load
    function initPayPal() {
      if (typeof paypal === 'undefined' || typeof paypal.Buttons === 'undefined') {
        console.error('PayPal SDK not loaded or Buttons not available');
        document.getElementById('error-message').innerHTML = 
          '<div class="error">PayPal SDK failed to load. Please check your internet connection.</div>';
        return;
      }

      console.log('PayPal SDK loaded, initializing buttons...');
      paypalLoaded = true;
      
      // Hide loading message
      const loadingMsg = document.getElementById('loading-message');
      if (loadingMsg) {
        loadingMsg.style.display = 'none';
      }

      try {
        paypal.Buttons({
      style: {
        layout: "vertical",
        color: "blue",
        shape: "rect",
        label: "pay",
        height: 50
      },
      createOrder: function(data, actions) {
        console.log('PayPal createOrder called');
        try {
          return actions.order.create({
            purchase_units: [{
              amount: {
                currency_code: "$currency",
                value: "$paypalAmount"
              },
              description: "Reservation for $escapedPropertyName",
              reference_id: "reservation-$escapedReservationId",
              payee: {
                email_address: "$escapedOwnerEmail"
              }
            }],
            application_context: {
              shipping_preference: "NO_SHIPPING"
            }
          });
        } catch (err) {
          console.error('Error in createOrder:', err);
          throw err;
        }
      },
      onApprove: function(data, actions) {
        console.log('Payment approved, orderId:', data.orderID);

        callFlutterHandler('paymentSuccess', {
          orderId: data.orderID,
          status: 'approved'
        });
      },
      onError: function(err) {
        console.error('PayPal error:', err);
        document.getElementById('error-message').innerHTML = 
          '<div class="error">Payment error: ' + err.message + '</div>';
        // Send error to Flutter
        callFlutterHandler('paymentError', { error: err.message });
      },
      onCancel: function(data) {
        console.log('Payment cancelled');
        // Send cancel message to Flutter
        callFlutterHandler('paymentCancel', {});
      }
        }).render('#paypal-button-container').then(function() {
          console.log('PayPal buttons rendered successfully');
          const loadingMsg = document.getElementById('loading-message');
          if (loadingMsg) {
            loadingMsg.style.display = 'none';
          }
        }).catch(function(err) {
          console.error('Error rendering PayPal buttons:', err);
          const loadingMsg = document.getElementById('loading-message');
          if (loadingMsg) {
            loadingMsg.style.display = 'none';
          }
          // Only show error if it's not the "Global messaging" warning
          if (!err.message || !err.message.includes('Global messaging not needed')) {
            document.getElementById('error-message').innerHTML = 
              '<div class="error">Failed to load PayPal buttons: ' + err.message + '</div>';
          }
        });
      } catch (err) {
        console.error('Exception initializing PayPal buttons:', err);
        const loadingMsg = document.getElementById('loading-message');
        if (loadingMsg) {
          loadingMsg.style.display = 'none';
        }
        if (!err.message || !err.message.includes('Global messaging not needed')) {
          document.getElementById('error-message').innerHTML = 
            '<div class="error">Failed to initialize PayPal: ' + err.message + '</div>';
        }
      }
    }

    // Wait for PayPal SDK to load
    function checkPayPalSDK() {
      console.log('Checking for PayPal SDK...');
      console.log('typeof paypal:', typeof paypal);
      
      if (typeof paypal !== 'undefined' && typeof paypal.Buttons !== 'undefined') {
        console.log('PayPal SDK found, initializing...');
        initPayPal();
      } else {
        console.log('PayPal SDK not ready yet, waiting...');
        setTimeout(checkPayPalSDK, 500);
      }
    }

    // Start checking when page loads
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', function() {
        console.log('DOM loaded, checking PayPal SDK...');
        checkPayPalSDK();
        // Timeout after 10 seconds
        setTimeout(function() {
          if (!paypalLoaded) {
            console.error('PayPal SDK failed to load after 10 seconds');
            const loadingMsg = document.getElementById('loading-message');
            if (loadingMsg) {
              loadingMsg.style.display = 'none';
            }
            document.getElementById('error-message').innerHTML = 
              '<div class="error">PayPal SDK failed to load. Please check your internet connection and try again.</div>';
          }
        }, 10000);
      });
    } else {
      // DOM already loaded
      console.log('DOM already loaded, checking PayPal SDK...');
      checkPayPalSDK();
      setTimeout(function() {
        if (!paypalLoaded) {
          console.error('PayPal SDK failed to load');
          const loadingMsg = document.getElementById('loading-message');
          if (loadingMsg) {
            loadingMsg.style.display = 'none';
          }
          document.getElementById('error-message').innerHTML = 
            '<div class="error">PayPal SDK failed to load. Please refresh.</div>';
        }
      }, 10000);
    }

    // Helper function to call Flutter handler
    // Uses URL scheme to avoid CSP/eval issues with PayPal's security policy
    function callFlutterHandler(handlerName, data) {
      console.log('Calling Flutter handler:', handlerName, data);
      
      // Check if we're on PayPal's domain (strict CSP)
      const isPayPalDomain = window.location.hostname.includes('paypal.com') || 
                            window.location.hostname.includes('paypalobjects.com');
      
      // Always use URL scheme when on PayPal's domain to avoid CSP issues
      // Also use URL scheme as primary method since it's safer and doesn't use eval
      try {
        if (handlerName === 'paymentSuccess') {
          const orderId = data && data.orderId ? data.orderId : '';
          const payerId = data && data.payerId ? data.payerId : '';
          const transactionId = data && data.transactionId ? data.transactionId : '';
          const url = 'paypal://success?orderId=' + encodeURIComponent(orderId) + 
                     '&status=success' +
                     (payerId ? '&payerId=' + encodeURIComponent(payerId) : '') +
                     (transactionId ? '&transactionId=' + encodeURIComponent(transactionId) : '');
          window.location.href = url;
          console.log('Using URL scheme for payment success');
          return true;
        } else if (handlerName === 'paymentCancel') {
          window.location.href = 'paypal://cancel';
          console.log('Using URL scheme for payment cancel');
          return true;
        } else if (handlerName === 'paymentError') {
          const errorMsg = data && data.error ? encodeURIComponent(data.error) : 'Unknown error';
          window.location.href = 'paypal://error?error=' + errorMsg;
          console.log('Using URL scheme for payment error');
          return true;
        }
      } catch (urlErr) {
        console.error('URL scheme failed:', urlErr);
        // Try JavaScript handler as last resort (only if not on PayPal domain)
        if (!isPayPalDomain) {
          try {
            if (typeof window.flutter_inappwebview !== 'undefined' && 
                typeof window.flutter_inappwebview.callHandler === 'function') {
              window.flutter_inappwebview.callHandler(handlerName, data);
              console.log('Using JavaScript handler as fallback');
              return true;
            }
          } catch (callErr) {
            console.error('JavaScript handler also failed:', callErr);
          }
        }
        return false;
      }
      
      return false;
    }
  </script>
</body>
</html>
''';
  }
}

class _PayPalPaymentDialog extends StatefulWidget {
  final int reservationId;
  final int propertyId;
  final double amount;
  final String currency;
  final String propertyName;
  final String checkIn;
  final String checkOut;
  final String ownerPayPalEmail;
  final bool isInstantPayment;

  const _PayPalPaymentDialog({
    required this.reservationId,
    required this.propertyId,
    required this.amount,
    required this.currency,
    required this.propertyName,
    required this.checkIn,
    required this.checkOut,
    required this.ownerPayPalEmail,
    required this.isInstantPayment,
  });

  @override
  State<_PayPalPaymentDialog> createState() => _PayPalPaymentDialogState();
}

class _PayPalPaymentDialogState extends State<_PayPalPaymentDialog> {
  InAppWebViewController? webViewController;
  bool _isLoading = true;
  String? _errorMessage;
  bool _paymentCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0077B6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'PayPal Payment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!_paymentCompleted)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context, null),
                    ),
                ],
              ),
            ),
            // Payment Details
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF8F9FA),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.propertyName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check-in: ${widget.checkIn}',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  Text(
                    'Check-out: ${widget.checkOut}',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${widget.currency} ${widget.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF0077B6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // WebView
            Expanded(
              child: _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                                _isLoading = true;
                              });
                              webViewController?.reload();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        InAppWebView(
                          initialData: InAppWebViewInitialData(
                            data: PayPalService._generatePayPalHTML(
                              amount: widget.amount,
                              currency: widget.currency,
                              propertyName: widget.propertyName,
                              reservationId: widget.reservationId.toString(),
                              ownerPayPalEmail: widget.ownerPayPalEmail,
                            ),
                            mimeType: 'text/html',
                            encoding: 'utf-8',
                            baseUrl: WebUri('https://www.paypal.com'),
                          ),
                          initialSettings: InAppWebViewSettings(
                            javaScriptEnabled: true,
                            domStorageEnabled: true,
                            useShouldOverrideUrlLoading: true,
                            useOnLoadResource: true,
                            allowsInlineMediaPlayback: true,
                            mediaPlaybackRequiresUserGesture: false,
                            thirdPartyCookiesEnabled: true,
                            mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                            allowsBackForwardNavigationGestures: false,
                            supportZoom: false,
                          ),
                          onWebViewCreated: (controller) {
                            webViewController = controller;
                            print('PayPal WebView created');
                            
                            // Register JavaScript handlers immediately
                            controller.addJavaScriptHandler(
                              handlerName: 'paymentSuccess',
                              callback: (args) {
                                print('Payment success handler called: $args');
                                if (args.isNotEmpty) {
                                  final data = args[0];
                                  if (data is Map) {
                                    _handlePaymentSuccess(data as Map<String, dynamic>);
                                  } else {
                                    _handlePaymentSuccess({'status': 'success', 'orderId': data.toString()});
                                  }
                                } else {
                                  _handlePaymentError({'error': 'Missing orderId from PayPal'});
                                }
                              },
                            );
                            controller.addJavaScriptHandler(
                              handlerName: 'paymentError',
                              callback: (args) {
                                print('Payment error handler called: $args');
                                if (args.isNotEmpty) {
                                  final data = args[0];
                                  if (data is Map) {
                                    _handlePaymentError(data as Map<String, dynamic>);
                                  } else {
                                    _handlePaymentError({'error': data.toString()});
                                  }
                                } else {
                                  _handlePaymentError({'error': 'Unknown error'});
                                }
                              },
                            );
                            controller.addJavaScriptHandler(
                              handlerName: 'paymentCancel',
                              callback: (args) {
                                print('Payment cancel handler called');
                                _handlePaymentCancel();
                              },
                            );
                            print('JavaScript handlers registered');
                          },
                          onLoadStart: (controller, url) {
                            setState(() {
                              _isLoading = true;
                            });
                            print('PayPal WebView loading: $url');
                          },
                          onLoadStop: (controller, url) async {
                            setState(() {
                              _isLoading = false;
                            });
                            print('PayPal WebView loaded: $url');
                            
                            // Only check URL - don't execute JavaScript on PayPal's pages (CSP restrictions)
                            _handleUrlChange(url.toString());
                          },
                          onConsoleMessage: (controller, consoleMessage) {
                            final level = consoleMessage.messageLevel.toString();
                            final message = consoleMessage.message;

                            // PayPal pages may show third-party JS warnings/errors such as Datadog,
                            // CSP, CORS, postMessage, tracking, or worker errors inside WebView.
                            // Do not block the payment screen because of these console messages.
                            print('PayPal Console [$level]: $message');

                            if (message.contains('Datadog') ||
                                message.contains('Session Replay') ||
                                message.contains('worker') ||
                                message.contains('Content Security Policy') ||
                                message.contains('unsafe-eval') ||
                                message.contains('CSP directive') ||
                                message.contains('CORS policy') ||
                                message.contains('Access-Control-Allow-Origin') ||
                                message.contains('XMLHttpRequest') ||
                                message.contains('postMessage') ||
                                message.contains('Global messaging')) {
                              print('PayPal non-critical WebView warning ignored.');
                              return;
                            }

                            // Important:
                            // Do not call setState(_errorMessage = ...) here.
                            // Real payment errors should be handled by PayPal onError/paymentError only.
                          },
                          onReceivedError: (controller, request, error) {
                            print('PayPal WebView load error: ${error.description}');
                            print('Failed URL: ${request.url}');

                            // Only show error if the MAIN frame failed.
                            // Ignore image/script/tracking/subresource failures.
                            if (request.isForMainFrame == true) {
                              setState(() {
                                _isLoading = false;
                                _errorMessage = 'Error loading PayPal: ${error.description}';
                              });
                            }
                          },
                          shouldOverrideUrlLoading: (controller, navigationAction) async {
                            final url = navigationAction.request.url.toString();
                            print('PayPal URL navigation: $url');
                            
                            // Handle PayPal success/cancel URLs (custom scheme)
                            if (url.startsWith('paypal://')) {
                              if (url.contains('success')) {
                                final uri = Uri.parse(url);
                                final orderId = uri.queryParameters['orderId'];
                                print('Payment success detected via URL: $orderId');
                                _handlePaymentSuccess({'orderId': orderId ?? 'unknown', 'status': 'success'});
                                return NavigationActionPolicy.CANCEL;
                              } else if (url.contains('cancel')) {
                                print('Payment cancel detected via URL');
                                _handlePaymentCancel();
                                return NavigationActionPolicy.CANCEL;
                              } else if (url.contains('error')) {
                                final uri = Uri.parse(url);
                                final error = uri.queryParameters['error'] ?? 'Unknown error';
                                print('Payment error detected via URL: $error');
                                _handlePaymentError({'error': error});
                                return NavigationActionPolicy.CANCEL;
                              }
                            }
                            
                            return NavigationActionPolicy.ALLOW;
                          },
                        ),
                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleUrlChange(String url) {
    print('PayPal URL changed: $url');
    // URL changes are handled via JavaScript handlers now
  }

  void _handlePaymentSuccess(Map<String, dynamic> data) async {
    try {
      setState(() {
        _isLoading = true;
        _paymentCompleted = true;
      });

      print('PayPal payment successful: $data');

      final orderId = '${data['orderId'] ?? data['transactionId'] ?? ''}';

      if (orderId.isEmpty || orderId == 'null') {
        throw Exception('Missing PayPal order ID.');
      }

      await api.capturePayPalOrder(orderId);

      final newStatus = widget.isInstantPayment ? 'Paid' : 'Partially Paid';
      print('Updating reservation status to $newStatus...');

      try {
        await api.updateReservationStatus(widget.reservationId, newStatus)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                print('Warning: updateReservationStatus timed out after 15 seconds');
                throw TimeoutException('Update reservation status timed out');
              },
            );
        print('Reservation status updated successfully');
      } catch (updateError) {
        print('Error updating reservation status (non-critical): $updateError');
      }

      try {
        print('Sending payment success notification...');
        await api.paymentSuccess(widget.reservationId)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                print('Warning: paymentSuccess timed out after 15 seconds');
                throw TimeoutException('Payment success notification timed out');
              },
            );
        print('Payment success notification sent');
      } catch (notificationError) {
        print('Error sending payment success notification (non-critical): $notificationError');
      }

      if (mounted) {
        print('Closing payment dialog with success status');
        Navigator.pop(context, {
          'status': 'success',
          'orderId': data['orderId'] ?? data['transactionId'],
          'transactionId': data['transactionId'] ?? data['orderId'],
        });
      }
    } catch (error) {
        print('Error processing payment success: $error');

        if (mounted) {
          Navigator.pop(context, {
            'status': 'error',
            'orderId': data['orderId'] ?? data['transactionId'],
            'transactionId': data['transactionId'] ?? data['orderId'],
            'error': 'Payment capture failed. Please contact support.',
          });
        }
      }
  }

  void _handlePaymentError(Map<String, dynamic> data) {
    print('PayPal payment error: $data');
      setState(() {
        _isLoading = false;
      _errorMessage = 'Unable to start PayPal payment. Please try again in a moment.';
        _paymentCompleted = false;
      });
  }

  void _handlePaymentCancel() {
    print('PayPal payment cancelled');
    if (mounted) {
      Navigator.pop(context, {'status': 'cancelled'});
    }
  }
}

