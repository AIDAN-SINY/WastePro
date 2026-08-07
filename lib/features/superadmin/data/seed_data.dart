import '../../../models/agence_model.dart';
import '../../../models/platform_user_model.dart';
import '../../../models/societe_model.dart';

/// Default platform data (same entities as `super-admin-desktop.html`).
///
/// Used by [PlatformStore] as its in-memory dataset and by the
/// Firestore-backed store to seed empty collections on first run.
const List<SocieteModel> seedSocietes = [
  SocieteModel(
    id: 'so1',
    raisonSociale: 'WastePro Douala Ltd',
    adresse: 'Bonanjo, Douala',
    telephone: '+237 233 42 10 10',
    email: 'contact@wastepro-douala.cm',
    status: 'Active',
  ),
  SocieteModel(
    id: 'so2',
    raisonSociale: 'WastePro Yaoundé SA',
    adresse: 'Bastos, Yaoundé',
    telephone: '+237 222 20 30 40',
    email: 'contact@wastepro-yde.cm',
    status: 'Active',
  ),
  SocieteModel(
    id: 'so3',
    raisonSociale: 'EcoCollecte Kribi',
    adresse: 'Centre-ville, Kribi',
    telephone: '+237 233 46 12 00',
    email: 'contact@ecocollecte-kribi.cm',
    status: 'Suspended',
  ),
];

const List<AgenceModel> seedAgences = [
  AgenceModel(
    id: 'ag1',
    societe: 'WastePro Douala Ltd',
    ville: 'Douala — Bonanjo',
    responsable: 'Jean Dooh',
    telephone: '+237 677 12 34 56',
    status: 'Active',
  ),
  AgenceModel(
    id: 'ag2',
    societe: 'WastePro Douala Ltd',
    ville: 'Douala — Bassa',
    responsable: 'Aïcha Bello',
    telephone: '+237 699 33 67 41',
    status: 'Active',
  ),
  AgenceModel(
    id: 'ag3',
    societe: 'WastePro Yaoundé SA',
    ville: 'Yaoundé',
    responsable: 'Marie Ekwalla',
    telephone: '+237 690 45 12 78',
    status: 'Active',
  ),
  AgenceModel(
    id: 'ag4',
    societe: 'EcoCollecte Kribi',
    ville: 'Kribi',
    responsable: 'Samuel Njoya',
    telephone: '+237 655 88 21 09',
    status: 'Suspended',
  ),
];

const List<PlatformUserModel> seedUtilisateurs = [
  PlatformUserModel(
    id: 'us1',
    nom: 'Jean Dooh',
    telephone: '+237 677 12 34 56',
    role: 'Agency Manager',
    agence: 'Douala — Bonanjo',
    status: 'Active',
  ),
  PlatformUserModel(
    id: 'us2',
    nom: 'Aïcha Bello',
    telephone: '+237 699 33 67 41',
    role: 'Agency Manager',
    agence: 'Douala — Bassa',
    status: 'Active',
  ),
  PlatformUserModel(
    id: 'us3',
    nom: 'Marie Ekwalla',
    telephone: '+237 690 45 12 78',
    role: 'Agency Manager',
    agence: 'Yaoundé',
    status: 'Active',
  ),
  PlatformUserModel(
    id: 'us4',
    nom: 'Platform Admin',
    telephone: '+237 6XX XXX XXX',
    role: 'General Administrator',
    agence: '—',
    status: 'Active',
  ),
];
