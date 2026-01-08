import 'package:temp_flutter/domain/entities/caregiver.dart';
import 'package:temp_flutter/data/models/caregiver_model.dart';

/// Mapper between Caregiver domain entity and CaregiverModel
class CaregiverMapper {
  CaregiverMapper._();

  /// Converts domain entity to model
  static CaregiverModel toModel(Caregiver caregiver) {
    return CaregiverModel.fromDomain(caregiver);
  }

  /// Converts model to domain entity
  static Caregiver toDomain(CaregiverModel model) {
    return model.toDomain();
  }

  /// Converts list of models to domain entities
  static List<Caregiver> toDomainList(List<CaregiverModel> models) {
    return models.map((model) => model.toDomain()).toList();
  }

  /// Converts list of domain entities to models
  static List<CaregiverModel> toModelList(List<Caregiver> caregivers) {
    return caregivers.map((caregiver) => CaregiverModel.fromDomain(caregiver)).toList();
  }
}

