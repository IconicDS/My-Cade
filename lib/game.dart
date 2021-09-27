import 'package:flutter/material.dart';

class Game {
  late String name;
  late int id;
  late Image icon;
  late String cat;

  Game(String name, int id, Image icon, String cat) {
    this.name = name;
    this.id = id;
    this.icon = icon;
    this.cat = cat;
  }
}
