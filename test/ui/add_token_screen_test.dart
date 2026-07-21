import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citadel_auth/core/models/profile.dart';
import 'package:citadel_auth/core/models/token.dart';
import 'package:citadel_auth/core/providers.dart';
import 'package:citadel_auth/data/database/vault_database.dart';
import 'package:citadel_auth/data/repositories/token_repository.dart';
import 'package:citadel_auth/ui/screens/add_token_screen.dart';

/// Records add/update calls so we can assert exactly what the screen persists,
/// without a real SQLCipher database (which needs a device/plugin and can't
/// run in the host test VM).
class _RecordingTokenRepository extends TokenRepository {
  _RecordingTokenRepository() : super(VaultDatabase());

  Token? added;
  Token? updated;

  @override
  Future<void> add(Token token) async => added = token;

  @override
  Future<void> update(Token token) async => updated = token;
}

/// The add-mode screen builds the QR scanner tab first, and mobile_scanner
/// talks to platform channels that don't exist in the test VM. Stub them so
/// the unawaited camera start doesn't surface a MissingPluginException.
void _mockScannerChannels(WidgetTester tester) {
  const methodChannel =
      MethodChannel('dev.steenbakker.mobile_scanner/scanner/method');
  const eventChannel =
      EventChannel('dev.steenbakker.mobile_scanner/scanner/event');

  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    methodChannel,
    (call) async {
      switch (call.method) {
        case 'state':
          return 1; // camera permission already authorized
        case 'start':
          return <String, Object?>{
            'textureId': 1,
            'size': {'width': 1280.0, 'height': 720.0},
            'currentTorchState': 0,
            'numberOfCameras': 1,
          };
        default:
          return null;
      }
    },
  );
  tester.binding.defaultBinaryMessenger.setMockStreamHandler(
    eventChannel,
    MockStreamHandler.inline(onListen: (arguments, events) {}),
  );
}

/// Pushes the screen from a host page so saving can pop back to it — popping
/// the root route directly would leave the navigator empty.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required _RecordingTokenRepository repo,
  Token? editToken,
  List<Profile> profiles = const [],
  List<TokenGroup> groups = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenRepositoryProvider.overrideWithValue(repo),
        profileListProvider.overrideWith((ref) async => profiles),
        groupListProvider.overrideWith((ref) async => groups),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddTokenScreen(editToken: editToken),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

TextField _textFieldWithLabel(WidgetTester tester, String label) =>
    tester.widget<TextField>(find.widgetWithText(TextField, label));

Token _editableToken() => Token(
      id: 'tok-1',
      issuer: 'GitHub',
      account: 'user@test.com',
      secret: 'JBSWY3DPEHPK3PXP',
      type: OtpType.totp,
      algorithm: Algorithm.sha256,
      digits: 8,
      period: 60,
      profileId: 'p1',
      groupId: 'g1',
    );

void main() {
  final profiles = [Profile(id: 'p1', name: 'Work', colorValue: 0xFF6366F1)];
  final groups = [TokenGroup(id: 'g1', profileId: 'p1', name: 'Main')];

  late _RecordingTokenRepository repo;

  setUp(() {
    repo = _RecordingTokenRepository();
  });

  group('edit mode', () {
    const secretLabel = 'Secret Key (cannot be changed)';

    testWidgets('secret field is read-only and obscured, reveal toggles it',
        (tester) async {
      await _pumpScreen(tester,
          repo: repo,
          editToken: _editableToken(),
          profiles: profiles,
          groups: groups);

      var secretField = _textFieldWithLabel(tester, secretLabel);
      expect(secretField.readOnly, isTrue);
      expect(secretField.obscureText, isTrue);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      secretField = _textFieldWithLabel(tester, secretLabel);
      expect(secretField.obscureText, isFalse);
      expect(secretField.readOnly, isTrue);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      secretField = _textFieldWithLabel(tester, secretLabel);
      expect(secretField.obscureText, isTrue);
    });

    testWidgets('advanced chips are disabled and never open the picker',
        (tester) async {
      await _pumpScreen(tester,
          repo: repo,
          editToken: _editableToken(),
          profiles: profiles,
          groups: groups);

      await tester.ensureVisible(find.text('Advanced'));
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();

      // The tap-affordance chevron is hidden when chips are disabled.
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      // Chip values reflect the token: TOTP / SHA256 / 8 digits / 60s.
      for (final chipValue in ['TOTP', 'SHA256', '8', '60s']) {
        await tester.ensureVisible(find.text(chipValue));
        await tester.tap(find.text(chipValue));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing,
            reason: 'tapping the $chipValue chip must not open the picker');
      }
    });

    testWidgets(
        'save keeps the original secret and OTP params, clears profile/group',
        (tester) async {
      final original = _editableToken();
      await _pumpScreen(tester,
          repo: repo,
          editToken: original,
          profiles: profiles,
          groups: groups);

      await tester.enterText(
          find.widgetWithText(TextField, 'Service / Issuer'), 'GitLab');
      await tester.enterText(
          find.widgetWithText(TextField, 'Account *'), 'renamed@test.com');
      await tester.pump();

      // Profile: Work -> None.
      await tester.ensureVisible(find.text('Work'));
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('None').last);
      await tester.pumpAndSettle();

      // Group: Main -> None.
      await tester.ensureVisible(find.text('Main'));
      await tester.tap(find.text('Main'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('None').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(repo.added, isNull);
      final saved = repo.updated;
      expect(saved, isNotNull);
      expect(saved!.id, original.id);
      expect(saved.issuer, 'GitLab');
      expect(saved.account, 'renamed@test.com');
      // Enrollment-fixed fields must survive the edit untouched.
      expect(saved.secret, original.secret);
      expect(saved.type, original.type);
      expect(saved.algorithm, original.algorithm);
      expect(saved.digits, original.digits);
      expect(saved.period, original.period);
      // "None" clears the assignment rather than keeping the old ids.
      expect(saved.profileId, isNull);
      expect(saved.groupId, isNull);

      // Saving pops back to the host page.
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('add mode', () {
    const secretLabel = 'Secret Key (Base32) *';

    Future<void> pumpAddMode(WidgetTester tester) async {
      _mockScannerChannels(tester);
      await _pumpScreen(tester, repo: repo);
      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();
    }

    testWidgets('secret field is editable and not obscured', (tester) async {
      await pumpAddMode(tester);

      final secretField = _textFieldWithLabel(tester, secretLabel);
      expect(secretField.readOnly, isFalse);
      expect(secretField.obscureText, isFalse);

      await tester.enterText(
          find.widgetWithText(TextField, secretLabel), 'JBSWY3DPEHPK3PXP');
      await tester.pump();
      expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
    });

    testWidgets('empty secret shows an error and does not save',
        (tester) async {
      await pumpAddMode(tester);

      await tester.enterText(
          find.widgetWithText(TextField, 'Account *'), 'user@test.com');
      // 'Add Token' is also the AppBar title, so scope to the save button.
      final saveButton = find.widgetWithText(ElevatedButton, 'Add Token');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text('Secret key is required'), findsOneWidget);
      expect(repo.added, isNull);
    });

    testWidgets('invalid Base32 secret shows an error and does not save',
        (tester) async {
      await pumpAddMode(tester);

      await tester.enterText(
          find.widgetWithText(TextField, 'Account *'), 'user@test.com');
      await tester.enterText(
          find.widgetWithText(TextField, secretLabel), 'not!base32!!');
      final saveButton = find.widgetWithText(ElevatedButton, 'Add Token');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text('Invalid Base32 secret key'), findsOneWidget);
      expect(repo.added, isNull);
    });
  });
}
