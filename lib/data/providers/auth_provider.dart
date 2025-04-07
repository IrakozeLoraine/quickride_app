import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickride/data/models/user_model.dart';
import 'package:quickride/data/models/rider_model.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _user;
  UserModel? _userModel;
  RiderModel? _riderModel;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get user => _user;
  UserModel? get userModel => _userModel;
  RiderModel? get riderModel => _riderModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isRider => _userModel?.userType == UserType.rider;

  AuthProvider() {
    _initAuthState();
  }

  void _initAuthState() {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        await _fetchUserData();
      } else {
        _userModel = null;
        _riderModel = null;
      }
      notifyListeners();
    });
  }

  Future<void> _fetchUserData() async {
    if (_user == null) return;

    try {
      _setLoading(true);
      final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
      
      if (userDoc.exists) {
        _userModel = UserModel.fromFirestore(userDoc);
        
        if (_userModel!.userType == UserType.rider) {
          final riderDoc = await _firestore.collection('riders').doc(_user!.uid).get();
          if (riderDoc.exists) {
            _riderModel = RiderModel.fromFirestore(riderDoc);
          }
        }
      }
      _setLoading(false);
    } catch (e) {
      _setError('Failed to fetch user data: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Sign in with email and password
  Future<bool> signInWithEmailPassword(String email, String password, BuildContext context) async {
    _setLoading(true);
    _clearError();
    final localizations = AppLocalizations.of(context)!;
    
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _user = userCredential.user;
      await _fetchUserData();
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      print(e);
      String errorMessage;
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = localizations.userNotFound;
          break;
        case 'wrong-password':
          errorMessage = localizations.wrongCredentials;
          break;
        case 'invalid-email':
          errorMessage = localizations.wrongCredentials;
          break;
        case 'user-disabled':
          errorMessage = localizations.userDisabled;
          break;
        case 'invalid-credential':
          errorMessage = localizations.wrongCredentials;
          break;
        default:
          errorMessage = 'An error occurred: ${e.message}';
      }
      
      _setError(errorMessage);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to sign in: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }
  
  // Register with email and password
  Future<bool> registerWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserType userType,
    required BuildContext context,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    _setLoading(true);
    _clearError();
    
    try {
      // Create the user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _user = userCredential.user;
      
      if (_user == null) {
        _setError(localizations.registrationFailed);
        _setLoading(false);
        return false;
      }
      
      // Update display name
      await _user!.updateDisplayName(name);
      
      // Create user in Firestore
      final userData = UserModel(
        id: _user!.uid,
        name: name,
        phone: _user!.phoneNumber ?? phone,
        email: email,
        userType: userType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _firestore.collection('users').doc(_user!.uid).set(userData.toFirestore());
      _userModel = userData;
      _setLoading(false);
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = localizations.emailAlreadyInUse;
          break;
        case 'invalid-email':
          errorMessage = localizations.invalidEmail;
          break;
        case 'weak-password':
          errorMessage = localizations.weakPassword;
          break;
        case 'operation-not-allowed':
          errorMessage = localizations.operationNotAllowed;
          break;
        default:
          errorMessage = '${localizations.somethingWentWrong}: ${e.message}';
      }
      
      _setError(errorMessage);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to register: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Register rider
  Future<bool> registerRider({
    required String licenseNumber,
    required String plateNumber,
    required String motorcycleModel,
    required GeoPoint currentLocation,
  }) async {
    if (_user == null || _userModel == null) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      final riderData = RiderModel(
        id: _user!.uid,
        name: _userModel!.name,
        phone: _userModel!.phone,
        email: _userModel!.email,
        profileImageUrl: _userModel!.profileImageUrl,
        createdAt: _userModel!.createdAt,
        updatedAt: DateTime.now(),
        licenseNumber: licenseNumber,
        plateNumber: plateNumber,
        motorcycleModel: motorcycleModel,
        currentLocation: currentLocation,
      );
      
      await _firestore.collection('riders').doc(_user!.uid).set(riderData.toFirestore());
      
      // Update user type to rider if not already
      if (_userModel!.userType != UserType.rider) {
        await _firestore.collection('users').doc(_user!.uid).update({
          'userType': UserType.rider.index,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
      
      _riderModel = riderData;
      await _fetchUserData(); // Refresh user data
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to register rider: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Reset password
  Future<bool> resetPassword(String email, BuildContext context) async {
    _setLoading(true);
    _clearError();
    final localizations = AppLocalizations.of(context)!;
    
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      
      switch (e.code) {
        case 'invalid-email':
          errorMessage = localizations.invalidEmail;
          break;
        case 'user-not-found':
          errorMessage = localizations.userNotFound;
          break;
        default:
          errorMessage = '${localizations.somethingWentWrong}: ${e.message}';
      }
      
      _setError(errorMessage);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to reset password: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _auth.signOut();
      _user = null;
      _userModel = null;
      _riderModel = null;
      _clearError();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to sign out: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
