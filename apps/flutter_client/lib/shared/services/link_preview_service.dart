import "package:polyphony_flutter_client/shared/models/link_preview.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

export "package:polyphony_flutter_client/shared/models/link_preview.dart";

abstract interface class LinkPreviewService {
  Future<Result<LinkPreview>> fetchPreview({required String url});
}
