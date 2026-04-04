import "package:polyphony_flutter_client/shared/result/result.dart";
import "package:polyphony_flutter_client/shared/services/link_preview_service.dart";
import "package:polyphony_flutter_client/shared/services/rest/rest_request_service_base.dart";

class RestLinkPreviewService extends RestRequestServiceBase
    implements LinkPreviewService {
  RestLinkPreviewService({required super.dio});

  final _cache = <String, LinkPreview>{};

  @override
  Future<Result<LinkPreview>> fetchPreview({required String url}) async {
    final cached = _cache[url];
    if (cached != null) {
      return Ok<LinkPreview>(cached);
    }

    final result = await performGetRequest<LinkPreview>(
      endpoint: "/api/v1/link-preview?url=${Uri.encodeQueryComponent(url)}",
      operation: "fetch link preview",
      decodeItem: (json) {
        final preview = LinkPreview(
          url: json["url"] as String? ?? url,
          title: json["title"] as String?,
          description: json["description"] as String?,
          imageUrl: json["image_url"] as String?,
        );
        return preview;
      },
    );

    if (result case Ok<LinkPreview>(:final value)) {
      _cache[url] = value;
    }

    return result;
  }
}
