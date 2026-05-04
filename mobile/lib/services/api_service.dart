import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/prediction_model.dart';

/// Handles all communication with the Flask backend.
class ApiService {
  // Reuse a single http.Client for connection keep-alive.
  final http.Client _client = http.Client();

  /// Sends [imageFile] to `/predict` and returns a [PredictionModel].
  Future<PredictionModel> predict(File imageFile) async {
    final uri     = Uri.parse(AppConstants.predictEndpoint);
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamed = await request.send().timeout(AppConstants.requestTimeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return PredictionModel.fromJson(
        json.decode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Server error ${response.statusCode}');
  }

  /// Fetches the latest XAU/USD price from `/live_price`.
  Future<LivePriceModel> getLivePrice() async {
    final response = await _client
        .get(Uri.parse(AppConstants.livePriceEndpoint))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return LivePriceModel.fromJson(
        json.decode(response.body) as Map<String, dynamic>,
      );
    }
    return const LivePriceModel();
  }

  void dispose() => _client.close();
}
