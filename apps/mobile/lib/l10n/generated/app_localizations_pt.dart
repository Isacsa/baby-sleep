// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Baby Sleep';

  @override
  String get tabSleep => 'Sono';

  @override
  String get tabStats => 'Estatísticas';

  @override
  String get tabRelax => 'Relaxar';

  @override
  String get tabInsights => 'Insights';

  @override
  String get homeGreeting => 'Olá, como correu a noite?';

  @override
  String homeBabyName(String name) {
    return 'Bebé $name';
  }

  @override
  String get homeSleepNow => 'Dormir Agora';

  @override
  String get homeWakeUp => 'Acordou';

  @override
  String get homeStartedAgo => 'Começar há:';

  @override
  String get homeOtherTime => 'Outra hora';

  @override
  String get homeRegisterPastSleep => 'Registar sono anterior:';

  @override
  String get homeOtherTimePast => 'Outra hora (sono anterior)';

  @override
  String get dayToday => 'Hoje';

  @override
  String get dayYesterday => 'Ontem';

  @override
  String dayTodayWithDate(int day, String month) {
    return 'Hoje, $day $month';
  }

  @override
  String dayYesterdayWithDate(int day, String month) {
    return 'Ontem, $day $month';
  }

  @override
  String get sessionsSleep => 'Sessões de sono';

  @override
  String sessionsCount(int count) {
    return '$count registos';
  }

  @override
  String get sessionNap => 'Sesta';

  @override
  String get sessionNight => 'Sono noturno';

  @override
  String get sessionCrossMidnight => 'Atravessa meia-noite';

  @override
  String get sessionStartedYesterday => 'Começou ontem';

  @override
  String get sessionOngoing => 'A dormir...';

  @override
  String get sessionInProgress => 'em curso';

  @override
  String get emptyStateNoRecords => 'Ainda sem registos hoje';

  @override
  String get emptyStateRecordsWillAppear =>
      'Os registos de sono aparecerão aqui';

  @override
  String get statsTitle => 'Estatísticas';

  @override
  String get statsWeek => 'Semana';

  @override
  String get statsMonth => 'Mês';

  @override
  String get statsNoData => 'Ainda sem dados';

  @override
  String get statsAvgPerDay => 'Média/dia';

  @override
  String get statsTotalNaps => 'Total sestas';

  @override
  String get statsDaysRecorded => 'Dias registados';

  @override
  String get relaxTitle => 'Relaxar';

  @override
  String get relaxComingSoon => 'Em breve';

  @override
  String get babiesTitle => 'Bebés';

  @override
  String get babiesAddNew => 'Adicionar bebé';

  @override
  String get babiesNoBabies => 'Ainda sem bebés adicionados';

  @override
  String babiesAge(int months) {
    return '$months meses';
  }

  @override
  String babiesAgeYears(int years) {
    return '$years ano(s)';
  }

  @override
  String get loginTitle => 'Bem-vindo';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginButton => 'Entrar';

  @override
  String get loginRegister => 'Criar conta';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonRetry => 'Tentar';

  @override
  String get commonOk => 'OK';

  @override
  String get summaryTotalSleep => 'Sono total';

  @override
  String summaryNaps(int count) {
    return '$count sestas';
  }

  @override
  String summarySessions(int count) {
    return '$count sessões';
  }

  @override
  String durationHours(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String durationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String get errorGeneric => 'Ocorreu um erro';

  @override
  String get errorNetwork => 'Erro de rede. Verifica a tua ligação.';

  @override
  String get errorNoBaby => 'Nenhum bebé selecionado';

  @override
  String get syncSyncing => 'A sincronizar...';

  @override
  String get syncSynced => 'Sincronizado';

  @override
  String get syncOffline => 'Offline';

  @override
  String syncPending(int count) {
    return '$count pendentes';
  }

  @override
  String get editSleepTitle => 'Editar sono';

  @override
  String get editSleepStart => 'Início';

  @override
  String get editSleepEnd => 'Fim';

  @override
  String get editSleepEndAfterStart =>
      'A hora de fim deve ser depois do início';

  @override
  String get deleteSleepTitle => 'Eliminar sono?';

  @override
  String deleteSleepConfirm(String start, String end) {
    return 'Tens a certeza que queres eliminar o sono das $start às $end?';
  }

  @override
  String get deleteSleepSuccess => 'Sono eliminado';

  @override
  String get overlapTitle => 'Já existe sono registado';

  @override
  String get overlapReplace => 'Substituir sono existente';

  @override
  String get overlapReplaced => 'Sono substituído';

  @override
  String get dstInvalidTime => 'Hora inválida';

  @override
  String dstTimeNotExist(String time) {
    return 'A hora $time não existe neste dia devido à mudança de hora (DST).\n\nPor favor, escolhe outra hora.';
  }

  @override
  String get preparingPermissions => 'A preparar permissões...';

  @override
  String get selectBaby => 'Seleciona um bebé';

  @override
  String get whatDay => 'Que dia?';

  @override
  String chosenTime(String time) {
    return 'Hora escolhida: $time';
  }

  @override
  String todayIsFuture(String time) {
    return 'Hoje às $time ainda é futuro';
  }

  @override
  String get otherDay => 'Outro dia…';

  @override
  String get cannotRegisterFuture => 'Não é possível registar sono no futuro';

  @override
  String get whatToRegister => 'O que queres registar?';

  @override
  String startAtTime(String day, String time) {
    return 'Início: $day às $time';
  }

  @override
  String get stillSleeping => 'Ainda está a dormir';

  @override
  String get registerCompleteSleep => 'Registar sono completo';

  @override
  String sleepingSince(String time) {
    return 'Já está a dormir desde $time';
  }

  @override
  String get whatToDo => 'O que queres fazer?';

  @override
  String get endSleepNow => 'Terminar sono agora';

  @override
  String get registerPastCompleteSleep => 'Registar sono completo do passado';

  @override
  String get sleepEnded => 'Sono terminado';

  @override
  String get whenSleepStarted => 'Quando começou o sono?';

  @override
  String get whenWokeUp => 'Quando acordou?';

  @override
  String get startTimeHelp => 'Hora de início do sono';

  @override
  String get endTimeHelp => 'Hora de fim do sono';

  @override
  String get startCannotBeFuture => 'A hora de início não pode estar no futuro';

  @override
  String get crossedMidnight => 'Atravessou meia-noite?';

  @override
  String crossedMidnightQuestion(String start, String end) {
    return 'Início às $start e fim às $end.\n\nO sono atravessou a meia-noite (dormiu ontem à noite, acordou hoje de manhã)?';
  }

  @override
  String get noCorrect => 'Não, corrigir';

  @override
  String get yes => 'Sim';

  @override
  String get endInFuture => 'Hora de fim no futuro';

  @override
  String get endCannotBeFuture => 'A hora de fim não pode estar no futuro.';

  @override
  String get useNow => 'Usar agora';

  @override
  String get syncTitle => 'Sincronização';

  @override
  String get syncNow => 'Sincronizar agora';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Fev';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Abr';

  @override
  String get monthMay => 'Mai';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Ago';

  @override
  String get monthSep => 'Set';

  @override
  String get monthOct => 'Out';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dez';
}
