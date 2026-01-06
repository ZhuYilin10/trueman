import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class LLMService {
  Future<String?> chatCompletion({
    required String systemPrompt,
    required String userMessage,
  });

  Future<List<double>?> getEmbedding(String text);
}

class VolcEngineService implements LLMService {
  final Dio _dio = Dio();

  String get _apiKey => dotenv.env['VOLC_API_KEY'] ?? '';
  String get _endpointId => dotenv.env['VOLC_ENDPOINT_ID'] ?? '';
  String get _baseUrl =>
      dotenv.env['VOLC_URL'] ??
      'https://ark.cn-beijing.volces.com/api/v3/chat/completions';

  String get _embeddingEndpointId =>
      dotenv.env['VOLC_EMBEDDING_ENDPOINT_ID'] ?? '';
  String get _embeddingUrl =>
      dotenv.env['VOLC_EMBEDDING_URL'] ??
      'https://ark.cn-beijing.volces.com/api/v3/embeddings';

  @override
  Future<String?> chatCompletion({
    required String systemPrompt,
    required String userMessage,
  }) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
        data: {
          'model': _endpointId,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessage}
          ],
          'stream': false,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content']?.trim();
        }
      }
    } catch (e) {
      print('[VolcEngineService] Chat Completion Failed: $e');
    }
    return null;
  }

  @override
  Future<List<double>?> getEmbedding(String text) async {
    try {
      final response = await _dio.post(
        _embeddingUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
        ),
        data: {
          'model': _embeddingEndpointId,
          'input': text,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['data'] != null && data['data'].isNotEmpty) {
          return (data['data'][0]['embedding'] as List)
              .map((e) => (e as num).toDouble())
              .toList();
        }
      }
    } catch (e) {
      print('[VolcEngineService] Embedding Failed: $e');
    }
    return null;
  }
}
