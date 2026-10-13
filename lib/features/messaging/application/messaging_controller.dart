// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/models/messaging.dart';

/// Contacts, each with the tone the assistant writes to them in.
///
/// The consequential part of this feature is [DeliveryMode]: with auto-send the assistant can
/// write to another person without the owner reading it first. Everything here is therefore
/// per contact and reversible — never a global switch that quietly applies to everybody.
class ContactsController extends AsyncNotifier<List<Contact>> {
  @override
  Future<List<Contact>> build() => ref.watch(armxApiProvider).contacts();

  /// Re-reads the list.
  Future<void> refresh() async {
    state = const AsyncValue<List<Contact>>.loading();
    state = await AsyncValue.guard(build);
  }

  /// Persists [contact] and adopts the backend's copy.
  ///
  /// The list only changes once the backend has answered: a delivery mode that appears to
  /// have changed but did not is a message sent without permission.
  Future<Contact> update(Contact contact) async {
    final Contact stored = await ref.read(armxApiProvider).updateContact(contact);
    final List<Contact> current = state.value ?? const <Contact>[];
    state = AsyncValue<List<Contact>>.data(
      current
          .map((Contact c) => c.id == stored.id ? stored : c)
          .toList(growable: false),
    );
    return stored;
  }
}

/// The contacts.
final AsyncNotifierProvider<ContactsController, List<Contact>> contactsProvider =
    AsyncNotifierProvider<ContactsController, List<Contact>>(
  ContactsController.new,
);

/// Tone profiles.
class ToneProfilesController extends AsyncNotifier<List<ToneProfile>> {
  @override
  Future<List<ToneProfile>> build() => ref.watch(armxApiProvider).toneProfiles();

  /// Re-reads them.
  Future<void> refresh() async {
    state = const AsyncValue<List<ToneProfile>>.loading();
    state = await AsyncValue.guard(build);
  }

  /// Persists [profile] and adopts the backend's copy.
  Future<ToneProfile> save(ToneProfile profile) async {
    final ToneProfile stored =
        await ref.read(armxApiProvider).saveToneProfile(profile);
    final List<ToneProfile> current = state.value ?? const <ToneProfile>[];
    final bool known = current.any((ToneProfile p) => p.id == stored.id);
    state = AsyncValue<List<ToneProfile>>.data(
      <ToneProfile>[
        if (known)
          for (final ToneProfile p in current) p.id == stored.id ? stored : p
        else
          ...current,
        if (!known) stored,
      ],
    );
    return stored;
  }
}

/// The tone profiles.
final AsyncNotifierProvider<ToneProfilesController, List<ToneProfile>>
    toneProfilesProvider =
    AsyncNotifierProvider<ToneProfilesController, List<ToneProfile>>(
  ToneProfilesController.new,
);

/// One tone profile by id.
final ProviderFamily<ToneProfile?, String> toneProfileByIdProvider =
    Provider.family<ToneProfile?, String>(
  (Ref ref, String id) => ref
      .watch(toneProfilesProvider)
      .value
      ?.where((ToneProfile profile) => profile.id == id)
      .firstOrNull,
);
