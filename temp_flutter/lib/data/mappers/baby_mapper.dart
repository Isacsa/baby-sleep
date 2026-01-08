import 'package:temp_flutter/domain/entities/baby.dart';
import 'package:temp_flutter/data/models/baby_model.dart';

/// Mapper between Baby domain entity and BabyModel
class BabyMapper {
  BabyMapper._();

  /// Converts domain entity to model
  static BabyModel toModel(Baby baby) {
    return BabyModel.fromDomain(baby);
  }

  /// Converts model to domain entity
  static Baby toDomain(BabyModel model) {
    return model.toDomain();
  }

  /// Converts list of models to domain entities
  static List<Baby> toDomainList(List<BabyModel> models) {
    return models.map((model) => model.toDomain()).toList();
  }

  /// Converts list of domain entities to models
  static List<BabyModel> toModelList(List<Baby> babies) {
    return babies.map((baby) => BabyModel.fromDomain(baby)).toList();
  }
}

