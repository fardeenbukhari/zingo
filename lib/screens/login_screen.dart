import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'main_navigation.dart';
import '../models/models.dart';
import '../providers/mock_data.dart';
import '../services/firebase_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/verification_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _captchaController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final FirebaseService _firebaseService = FirebaseService();
  final VerificationService _verifService = VerificationService();

  bool _isLoading = false;
  bool _otpSent = false;
  bool _isCaptchaStep = false;
  String? _captchaImageBase64;
  String? _refId;
  int _resendCooldown = 0; // countdown seconds for rate-limit
  Organization? _selectedOrg;
  List<Organization> _allOrgs = [];

  @override
  void initState() {
    super.initState();
    debugPrint("MapPingr [v1.2.1]: Login Screen Initialized");
    _fetchOrganizations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
    });
  }

  Future<void> _fetchOrganizations() async {
    try {
      final orgs = await _firebaseService.getOrganizations();
      if (mounted) {
        setState(() {
          _allOrgs = orgs;
          // Add default if empty
          if (_allOrgs.isEmpty) {
            _allOrgs = [
              Organization(
                id: 'sharda',
                name: 'Sharda University',
                domain: 'sharda.ac.in',
              ),
            ];
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching orgs: $e');
      if (mounted) {
        setState(() {
          _allOrgs = [
            Organization(
              id: 'sharda',
              name: 'Sharda University',
              domain: 'sharda.ac.in',
            ),
          ];
        });
      }
    }
  }

  void _showOrgSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Your Organization',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: _inputDecoration(
                'Search organizations...',
                Icons.search,
              ),
              onChanged: (value) {
                // Filter logic can be added here
              },
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: _allOrgs.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final org = _allOrgs[index];
                  return ListTile(
                    leading: const Icon(
                      Icons.business,
                      color: Color(0xFF1DE9B6),
                    ),
                    title: Text(org.name),
                    subtitle: Text('Emails ending in @${org.domain}'),
                    onTap: () {
                      setState(() => _selectedOrg = org);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _aadhaarController.dispose();
    _otpController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    setState(() => _resendCooldown = seconds);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown--);
      return _resendCooldown > 0;
    });
  }

  bool _isRateLimitError(String message) {
    return message.toLowerCase().contains('45 second') ||
        message.toLowerCase().contains('try after') ||
        message.toLowerCase().contains('rate limit') ||
        message.toLowerCase().contains('otp generated for this');
  }

  bool _isInvalidAadhaarError(String message) {
    final m = message.toLowerCase();
    return m.contains('invalid uid') ||
        m.contains('invalid aadhaar') ||
        m.contains('uid not found') ||
        m.contains('aadhaar not found') ||
        m.contains('invalid resident') ||
        m.contains('does not exist') ||
        m.contains('not registered') ||
        m.contains('no record found');
  }

  /// Verhoeff checksum for Aadhaar number validation.
  bool _isValidAadhaar(String aadhaar) {
    if (aadhaar.length != 12 || !RegExp(r'^[0-9]+$').hasMatch(aadhaar)) {
      return false;
    }
    // First digit cannot be 0 or 1
    if (aadhaar[0] == '0' || aadhaar[1] == '0') return false;

    const d = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
      [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
      [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
      [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
      [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
      [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
      [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
      [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
      [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
    ];
    const p = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
      [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
      [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
      [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
      [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
      [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
      [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
    ];

    int c = 0;
    final rev = aadhaar.split('').reversed.toList();
    for (int i = 0; i < rev.length; i++) {
      c = d[c][p[i % 8][int.parse(rev[i])]];
    }
    return c == 0;
  }

  Future<void> _handleAadhaarRequest() async {
    final raw = _aadhaarController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.length != 12) {
      _showError('Please enter a valid 12-digit Aadhaar number');
      return;
    }
    if (!_isValidAadhaar(raw)) {
      _showError('Invalid Aadhaar number. Please check and try again.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final sanitizedAadhaar = _aadhaarController.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );

      final result = await _verifService.submitAadhaar(sanitizedAadhaar);

      if (result['success']) {
        setState(() {
          _isCaptchaStep = true;
          _refId = result['sessionId'];
          _captchaImageBase64 = result['captchaImage'];
          _captchaController.clear();
        });
        _showInfo('Please enter the captcha to receive OTP.');
      } else {
        final msg =
            result['message'] ?? result['error'] ?? 'Aadhaar request failed';
        if (_isRateLimitError(msg)) {
          final match = RegExp(r"wait (\d+) seconds").firstMatch(msg);
          int waitTime = match != null ? int.parse(match.group(1)!) : 30;
          _startCooldown(waitTime);
          _showError(msg);
        } else if (_isInvalidAadhaarError(msg)) {
          _showError('Invalid Aadhaar number. Please check and try again.');
        } else {
          _showError(msg);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCooldown > 0) {
      _showError('Please wait $_resendCooldown seconds before resending OTP');
      return;
    }
    setState(() => _isLoading = true);
    try {
      _otpController.clear();
      // Sanitize on resend too
      final sanitizedAadhaar = _aadhaarController.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final result = await _verifService.submitAadhaar(sanitizedAadhaar);

      if (result['success']) {
        setState(() {
          _refId = result['sessionId'];
          _captchaImageBase64 = result['captchaImage'];
          _isCaptchaStep = true;
          _otpSent = false;
          _captchaController.clear();
        });
        _showInfo('Please solve the new captcha to resend OTP');
      } else {
        final msg = result['message'] ?? 'Resend failed';
        if (_isRateLimitError(msg)) {
          // Attempt to extract Exact cooldown from the service message
          final match = RegExp(r"wait (\d+) seconds").firstMatch(msg);
          int waitTime = match != null ? int.parse(match.group(1)!) : 30;
          _startCooldown(waitTime);
          _showError(msg); // Display the accurate service layer error
        } else {
          _showError(msg);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCaptchaSubmit() async {
    if (_captchaController.text.isEmpty) {
      _showError('Please enter the captcha shown');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _verifService.requestOTP(
        _refId!,
        _captchaController.text,
      );

      if (result['success']) {
        setState(() {
          _isCaptchaStep = false;
          _otpSent = true;
          _otpController.clear();
        });
        _showInfo(result['message'] ?? 'OTP sent to your mobile');
      } else {
        final msg = result['message'] ?? result['error'] ?? 'Invalid Captcha';
        if (_isInvalidAadhaarError(msg)) {
          // Go back to Aadhaar input step
          setState(() {
            _isCaptchaStep = false;
            _otpSent = false;
          });
          _showError('Invalid Aadhaar number. Please check and try again.');
        } else {
          _showError(msg);
        }
      }
    } catch (e) {
      _showError('Captcha error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAadhaarOtp() async {
    if (_otpController.text.length != 6) {
      _showError('Please enter 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_refId == null) {
        throw 'Verification session missing. Please resend OTP.';
      }

      final result = await _verifService.verifyOtp(
        _refId!,
        _otpController.text,
      );

      if (result['success']) {
        // Extract real name from Aadhaar KYC data payload if available
        final aadhaarNum = _aadhaarController.text.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );
        String aadhaarName =
            'User ****${aadhaarNum.substring(8)}'; // masked fallback
        String? aadhaarGender;

        if (result['userData'] != null && result['userData'] is Map) {
          final ud = result['userData'] as Map;
          // Try multiple field names UIDAI may use
          final String? realName =
              (ud['name'] ??
                      ud['fullName'] ??
                      ud['resident_name'] ??
                      ud['enName'])
                  ?.toString();
          if (realName != null && realName.trim().isNotEmpty) {
            aadhaarName = realName.trim();
          }
          final String? realGender = (ud['gender'] ?? ud['sex'])?.toString();
          if (realGender != null && realGender.isNotEmpty) {
            aadhaarGender = realGender;
          }
          debugPrint(
            'Aadhaar name found: $aadhaarName  gender: $aadhaarGender',
          );
        }

        String aadhaarCardNumber = _aadhaarController.text.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );

        final existingUser = await _firebaseService.getUserProfile(
          aadhaarCardNumber,
        );

        if (existingUser != null) {
          // Update name/gender if we now have a real name from UIDAI
          if (aadhaarName.isNotEmpty &&
              !aadhaarName.startsWith('User ****') &&
              existingUser.name.startsWith('User ****')) {
            final updated = existingUser.copyWith(
              name: aadhaarName,
              gender: aadhaarGender ?? existingUser.gender,
            );
            await _firebaseService.saveUserProfile(updated);
            currentUser = updated;
          } else {
            currentUser = existingUser;
          }

          // Persist session for web refresh
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('session_uid', aadhaarCardNumber);

          _showInfo('Aadhaar Verified! Welcome back, $aadhaarName.');
          _navigateToHome();
        } else {
          // New User
          final newUser = User(
            userId: aadhaarCardNumber,
            name: aadhaarName,
            email: "resident_$aadhaarCardNumber@aadhaar.local",
            avatar: 'https://i.pravatar.cc/150?u=$aadhaarCardNumber',
            gender: aadhaarGender,
            interests: [],
            pingPoints: 100,
            isVerified: true,
            isAadhaarVerified: true,
            linkedAadhaar: aadhaarCardNumber,
            joinedAt: DateTime.now(),
          );

          await _firebaseService.saveUserProfile(newUser);
          currentUser = newUser;

          // Persist session for web refresh
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('session_uid', aadhaarCardNumber);

          _showInfo('Aadhaar Verified! Welcome, $aadhaarName.');
          _navigateToHome();
        }
      } else {
        final msg = result['message'] ?? 'Invalid OTP';
        final details = result['details'];
        _showError(details != null ? '$msg ($details)' : msg);
      }
    } catch (e) {
      debugPrint("MapPingr Login Error: $e");
      _showError('Verification error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      auth.UserCredential? userCredential;
      String? userEmail;
      String? userDisplayName;
      String? userPhotoUrl;

      if (kIsWeb) {
        final auth.GoogleAuthProvider googleProvider =
            auth.GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        userCredential = await auth.FirebaseAuth.instance.signInWithPopup(
          googleProvider,
        );
        userEmail = userCredential.user?.email;
        userDisplayName = userCredential.user?.displayName;
        userPhotoUrl = userCredential.user?.photoURL;
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final auth.AuthCredential credential =
            auth.GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );

        userCredential = await auth.FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        userEmail = googleUser.email;
        userDisplayName =
            userCredential.user?.displayName ?? googleUser.displayName;
        userPhotoUrl = userCredential.user?.photoURL ?? googleUser.photoUrl;
      }

      if (userCredential.user != null && userEmail != null) {
        final normalizedEmail = userEmail.toLowerCase();

        if (_selectedOrg != null) {
          final domain = _selectedOrg!.domain.toLowerCase();
          final isOrgEmail =
              normalizedEmail.endsWith('@$domain') ||
              normalizedEmail.endsWith('.$domain');

          if (!isOrgEmail) {
            await auth.FirebaseAuth.instance.signOut();
            if (!kIsWeb) await GoogleSignIn().signOut();
            _showError(
              'Only @$domain emails are allowed for ${_selectedOrg!.name}.',
            );
            if (mounted) setState(() => _isLoading = false);
            return;
          }
        } else {
          // Fallback check
          final isSharda =
              normalizedEmail.endsWith('@sharda.ac.in') ||
              normalizedEmail.endsWith('.sharda.ac.in');
          if (!isSharda) {
            await auth.FirebaseAuth.instance.signOut();
            if (!kIsWeb) await GoogleSignIn().signOut();
            _showError('Please select your organization first.');
            if (mounted) setState(() => _isLoading = false);
            return;
          }
        }

        debugPrint("MapPingr: Attempting login with email: $normalizedEmail");

        final profile = await _firebaseService.getUserProfile(
          userCredential.user!.uid,
        );

        if (profile != null) {
          currentUser = profile;
          if (userPhotoUrl != null && profile.avatar != userPhotoUrl) {
            final updated = profile.copyWith(avatar: userPhotoUrl);
            await _firebaseService.saveUserProfile(updated);
            currentUser = updated;
          }
        } else {
          final newUser = User(
            userId: userCredential.user!.uid,
            name: userDisplayName ?? normalizedEmail.split('@')[0],
            email: normalizedEmail,
            avatar:
                userPhotoUrl ??
                'https://i.pravatar.cc/150?u=${userCredential.user!.uid}',
            interests: [],
            pingPoints: 50,
            isVerified: true,
            isAadhaarVerified: false,
            organization: _selectedOrg?.name ?? 'University',
            joinedAt: DateTime.now(),
          );
          await _firebaseService.saveUserProfile(newUser);
          currentUser = newUser;
        }

        // Persist session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_uid', currentUser.userId);

        _navigateToHome();
      }
    } catch (e, stack) {
      debugPrint("Google Sign-In Error: $e");
      debugPrint("Stack Trace: $stack");
      _showError('Google Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfo(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1DE9B6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigation()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                // Logo/Brand Section
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to Icon if image doesn't exist yet
                          return const Icon(
                            Icons.radar,
                            size: 64,
                            color: Color(0xFF1DE9B6),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Welcome to MapPingr',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select your organization or verify with Aadhaar to get started',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black45),
                ),
                const SizedBox(height: 40),

                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1DE9B6),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Find Organization
                          if (_selectedOrg == null)
                            ElevatedButton.icon(
                              onPressed: _showOrgSelector,
                              icon: const Icon(Icons.business_outlined),
                              label: const Text(
                                'FIND YOUR ORGANIZATION',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                elevation: 0,
                              ),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1DE9B6,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF1DE9B6),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.verified,
                                        color: Color(0xFF1DE9B6),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedOrg!.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'Domain: @${_selectedOrg!.domain}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            setState(() => _selectedOrg = null),
                                        child: const Text('CHANGE'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _handleGoogleSignIn,
                                  icon: Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                                    height: 20,
                                  ),
                                  label: const Text(
                                    'CONTINUE WITH GOOGLE',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side: const BorderSide(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 24),

                          // 2. Aadhaar Section
                          const Row(
                            children: [
                              Expanded(child: Divider(color: Colors.black12)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR LOGIN USING AADHAAR',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.black26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.black12)),
                            ],
                          ),
                          const SizedBox(height: 24),

                          if (!_isCaptchaStep && !_otpSent)
                            TextField(
                              controller: _aadhaarController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              maxLength: 12,
                              decoration: _inputDecoration(
                                '12-Digit Aadhaar',
                                Icons.credit_card,
                              ),
                            )
                          else if (_isCaptchaStep)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_captchaImageBase64 != null)
                                  Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.black12,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Image.memory(
                                        base64Decode(_captchaImageBase64!),
                                        height: 60,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _captchaController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: _inputDecoration(
                                    'Enter Captcha',
                                    Icons.security,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _handleAadhaarRequest,
                                  child: const Text(
                                    'Refresh Captcha / Change Aadhaar',
                                    style: TextStyle(color: Colors.black45),
                                  ),
                                ),
                              ],
                            )
                          else
                            TextField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: _inputDecoration(
                                'Enter 6-Digit OTP',
                                Icons.lock_clock_outlined,
                              ),
                            ),

                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _otpSent
                                ? _handleAadhaarOtp
                                : (_isCaptchaStep
                                      ? _handleCaptchaSubmit
                                      : _handleAadhaarRequest),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1DE9B6),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _otpSent
                                ? const Text(
                                    'VERIFY AADHAAR',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  )
                                : (_isCaptchaStep
                                      ? const Text(
                                          'SEND OTP',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        )
                                      : const Text(
                                          'LOGIN USING AADHAAR',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        )),
                          ),
                          if (_otpSent) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: (_isLoading || _resendCooldown > 0)
                                  ? null
                                  : _handleResendOtp,
                              child: Text(
                                _resendCooldown > 0
                                    ? 'Resend OTP (wait ${_resendCooldown}s)'
                                    : 'Resend OTP',
                                style: TextStyle(
                                  color: _resendCooldown > 0
                                      ? Colors.black26
                                      : Colors.black.withOpacity(0.6),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.black38),
      filled: true,
      fillColor: Colors.black.withOpacity(0.04),
      counterText: "",
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}
