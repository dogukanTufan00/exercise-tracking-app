import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../data/rest/rest_controller.dart';

/// Dinlenme denetleyicisini sağlayıcıdan alır; sağlayıcı yoksa (testler) `null`.
RestController? readRestController(BuildContext context) {
  try {
    return context.read<RestController>();
  } on ProviderNotFoundException {
    return null;
  }
}
