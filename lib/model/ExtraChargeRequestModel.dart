class ExtraChargeRequestModel {
  int? key;
  String? value;

  ExtraChargeRequestModel({this.value, this.key});

  ExtraChargeRequestModel.fromJson(Map<String, dynamic> json) {
    key = 1;
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = 1;
    data['key'] = this.key!;
    return data;
  }
}
