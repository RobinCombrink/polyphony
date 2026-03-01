enum ChannelType {
  text("text"),
  voice("voice");

  const ChannelType(this.apiValue);

  final String apiValue;

  static ChannelType fromApiValue(String? rawValue) {
    final normalizedValue = rawValue?.trim().toLowerCase();

    return ChannelType.values.firstWhere(
      (channelType) => channelType.apiValue == normalizedValue,
      orElse: () => ChannelType.text,
    );
  }
}
