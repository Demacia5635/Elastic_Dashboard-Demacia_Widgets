const bool isWPILib = bool.fromEnvironment('ELASTIC_WPILIB');

const String logoPath = 'assets/logos/logo.png';

const String appTitle =
    !isWPILib ? 'Elastic + Demacia Widgets' : 'Elastic (WPILib)';
