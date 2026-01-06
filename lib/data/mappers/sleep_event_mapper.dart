import '../../domain/entities/sleep_event.dart';
import '../models/sleep_event_model.dart';

/// Mapper between SleepEvent domain entity and SleepEventModel
class SleepEventMapper {
  SleepEventMapper._();

  /// Converts domain entity to model
  static SleepEventModel toModel(SleepEvent event) {
    return SleepEventModel.fromDomain(event);
  }

  /// Converts model to domain entity
  static SleepEvent toDomain(SleepEventModel model) {
    return model.toDomain();
  }

  /// Converts list of models to domain entities
  static List<SleepEvent> toDomainList(List<SleepEventModel> models) {
    return models.map((model) => model.toDomain()).toList();
  }

  /// Converts list of domain entities to models
  static List<SleepEventModel> toModelList(List<SleepEvent> events) {
    return events.map((event) => SleepEventModel.fromDomain(event)).toList();
  }
}

