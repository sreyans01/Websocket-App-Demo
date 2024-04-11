
extension NetworkConstants on Object {
  static String getWebsocketUrl(String firstName) {
    return "ws://122.179.143.201:8089/websocket?sessionID=$firstName&userID=$firstName&apiToken=$firstName";
  }
}
