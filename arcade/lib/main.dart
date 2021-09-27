import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:arcade/romGame.dart';
import 'package:arcade/steamGame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win_gamepad/gamepad.dart';
import 'package:http/http.dart' as http;
import 'package:win_gamepad/gamepad_layout.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';

import 'game.dart';

double imgWidth = 1;
String showPage = "desktop";
String selectedSearch = "ALL";
Widget selectedButton = Container();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My-Cade V:1.0',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WindowListener {
  late SharedPreferences prefs;
  List<Game> deskGames = [];
  Gamepad gamepad = Gamepad();
  final _focusNode = FocusNode();
  bool lockJoystick = false;
  bool hasFocus = true;
  List<String> search = [
    "ALL",
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z"
  ];

  @override
  void onWindowFocus() {
    hasFocus = true;
  }

  @override
  void onWindowBlur() {
    hasFocus = false;
  }

  @override
  void initState() {
    WindowManager.instance.addListener(this);
    WindowManager.instance.setFullScreen(true);

    initGamepad();
    initPrefs();

    super.initState();
  }

  void reloadGames() {
    if (showPage == "desktop") {
      loadSteamGames();
    } else {
      loadRoms();
    }
  }

  void initGamepad() async {
    gamepad.initialize(onCallback: (gamepadState) async {
      if (hasFocus) {
        if (!lockJoystick) {
          if (gamepadState.isPressed(GamepadButton.a)) {
            if (selectedButton.runtimeType == MyCustomButton) {
              (selectedButton as ElevatedButton).onPressed!();
              lockJoystick = true;
            }
          }
          if (gamepadState.leftThumbX > -257) {
            _focusNode.focusInDirection(TraversalDirection.right);
            lockJoystick = true;
          }
          if (gamepadState.leftThumbX < -257) {
            _focusNode.focusInDirection(TraversalDirection.left);
            lockJoystick = true;
          }
          if (gamepadState.leftThumbY > 256) {
            _focusNode.focusInDirection(TraversalDirection.up);
            lockJoystick = true;
          }
          if (gamepadState.leftThumbY < 256) {
            _focusNode.focusInDirection(TraversalDirection.down);
            lockJoystick = true;
          }
        } else {
          if (gamepadState.leftThumbX == -257 &&
              gamepadState.leftThumbY == 256 &&
              !gamepadState.isPressed(GamepadButton.a)) {
            lockJoystick = false;
          }
        }
      }
      setState(() {});
    });
  }

  void initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    if (prefs.getString("SteamPath") == null) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Container(
                height: 106,
                width: 420,
                child: Column(
                  children: <Widget>[
                    Text(
                      "Please select the path to your 'SteamLibrary' folder...",
                      style: TextStyle(
                        fontFamily: "Poppins-Semibold",
                      ),
                    ),
                    Padding(padding: EdgeInsets.all(9)),
                    ElevatedButton(
                      child: Image(
                        image: AssetImage("assets/images/folder.png"),
                        width: 64,
                        height: 64,
                      ),
                      onPressed: () async {
                        String? result =
                            await FilePicker.platform.getDirectoryPath();
                        String path = result!;
                        while (!(path.endsWith('SteamLibrary'))) {
                          result = await FilePicker.platform.getDirectoryPath();
                          path = result!;
                        }
                        prefs.setString(
                            "SteamPath", path.replaceAll("\\", "/"));
                        reloadGames();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          });
    }

    if (prefs.getString("RomsPath") == null) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Container(
                height: 106,
                width: 420,
                child: Column(
                  children: <Widget>[
                    Text(
                      "Please select the path to your 'Roms' folder...",
                      style: TextStyle(
                        fontFamily: "Poppins-Semibold",
                      ),
                    ),
                    Padding(padding: EdgeInsets.all(9)),
                    ElevatedButton(
                      child: Image(
                        image: AssetImage("assets/images/folder.png"),
                        width: 64,
                        height: 64,
                      ),
                      onPressed: () async {
                        String? result =
                            await FilePicker.platform.getDirectoryPath();
                        String path = result!;
                        prefs.setString("RomsPath", path.replaceAll("\\", "/"));
                        if (deskGames.isEmpty) {
                          reloadGames();
                        }
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          });
    }

    if (deskGames.isEmpty) {
      reloadGames();
    }
  }

  void loadSteamGames() async {
    setState(() {
      deskGames.clear();
    });

    String path = prefs.getString("SteamPath")!;
    final directory = Directory(path);
    File libFolder = File("${directory.path}/libraryfolder.vdf");
    List<String> libLines = await libFolder.readAsLines();

    String steamDir = "";
    for (String s in libLines) {
      if (s.contains("launcher")) {
        steamDir = s.split("\"")[3].split("steam.exe")[0];
        break;
      }
    }

    final appDirectory = Directory("${directory.path}/steamapps/common");
    var url =
        Uri.parse("http://api.steampowered.com/ISteamApps/GetAppList/v0002/");
    Response response = await http.get(url);
    String appList = response.body.split("{\"applist\":{\"apps\":")[1];
    List<String> l = appList.split("");
    l.removeLast();
    l.removeLast();
    appList = l.join();
    List<dynamic> list = json.decode(appList);
    List<SteamGame> games = [];
    for (var v in list) {
      SteamGame e = SteamGame.fromJson(v);
      games.add(e);
    }

    // Stream<FileSystemEvent> steamChanged = directory.watch();

    Stream<FileSystemEntity> folders = appDirectory.list();
    folders.forEach((element) async {
      String gameDir = element.path;
      String gameName = gameDir.split('\\')[1].split('\'')[0];

      for (SteamGame g in games) {
        if (g.name.toLowerCase() == gameName.toLowerCase()) {
          File headerFile =
              File("$steamDir/appcache/librarycache/${g.appId}_header.jpg");
          Image img = Image.file(headerFile);

          setState(() {
            Game newGame = Game(g.name, g.appId, img, "desktop");
            deskGames.add(newGame);
          });
          break;
        }
      }
    });
  }

  void loadRoms() async {
    setState(() {
      deskGames.clear();
    });

    String path = prefs.getString("RomsPath")!;
    final directory = Directory(path);
    Stream<FileSystemEntity> files = directory.list();

    String res = await DefaultAssetBundle.of(context)
        .loadString("assets/images/rom_images.json");
    List<dynamic> list = json.decode(res);
    List<RomGame> games = [];
    for (var v in list) {
      RomGame e = RomGame.fromJson(v);
      games.add(e);
    }

    files.forEach((f) async {
      String name = f.path.split("\\")[f.path.split("\\").length - 1];
      String category = "apple";
      if (name.endsWith("z64")) {
        category = "n64";
      }
      if (name.endsWith("smd") ||
          name.endsWith("32x") ||
          name.endsWith("s28") ||
          name.endsWith("sc") ||
          name.endsWith("zsg") ||
          name.endsWith("sg")) {
        category = "sega";
      }
      if (name.endsWith("iso")) {
        category = "gamecube";
      }
      if (name.endsWith("nes") || name.endsWith("sfc")) {
        category = "nes";
      }
      if (name.endsWith("gba") || name.endsWith("gbc") || name.endsWith("gb")) {
        category = "gba";
      }
      if (name.endsWith("32X") ||
          name.endsWith("st") ||
          name.endsWith("atr") ||
          name.endsWith("bin") ||
          name.endsWith("a26") ||
          name.endsWith("lnx")) {
        category = "atari";
      }

      Image img = Image.network(
          "http://chipsbudget.com/arcade_images/apple/%2788%20Games.png");
      int points = 0;
      for (RomGame g in games) {
        if (g.category == category) {
          int np = 0;
          String imgName = g.name;
          for (String s in name.split(" ")) {
            if (imgName.contains(s)) {
              np += 1;
            }
          }
          if (np > points) {
            points = np;
            img = Image.network(g.url);
          }
        }
      }

      setState(() {
        Game newGame = Game(name, 0, img, category);
        deskGames.add(newGame);
      });
    });

    setState(() {});
  }

  void setPage(String s) {
    setState(() {
      showPage = s;
    });
    reloadGames();
    setState(() {});
  }

  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double buttonWidth = (MediaQuery.of(context).size.width *
            MediaQuery.of(context).size.height) /
        25000;

    ButtonStyle _buttonStyle = ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith((state) =>
            state.contains(MaterialState.focused)
                ? Colors.white
                : Colors.transparent),
        padding: MaterialStateProperty.resolveWith((state) =>
            state.contains(MaterialState.focused)
                ? EdgeInsets.all(20)
                : EdgeInsets.all(20)),
        shadowColor: MaterialStateProperty.resolveWith((state) =>
            state.contains(MaterialState.focused)
                ? Colors.red
                : Colors.transparent),
        shape: MaterialStateProperty.resolveWith((state) =>
            state.contains(MaterialState.focused)
                ? CircleBorder(side: BorderSide(color: Colors.transparent))
                : CircleBorder(side: BorderSide(color: Colors.transparent))));

    ButtonStyle _searchStyle = ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith((state) =>
            state.contains(MaterialState.focused)
                ? Colors.red
                : Colors.transparent),
        padding: MaterialStateProperty.resolveWith((state) =>
            state.contains(MaterialState.focused)
                ? EdgeInsets.all(15)
                : EdgeInsets.all(15)),
        shadowColor: MaterialStateProperty.resolveWith((state) =>
            state.contains(MaterialState.focused)
                ? Colors.red
                : Colors.transparent),
        shape: MaterialStateProperty.resolveWith((state) =>
            state.contains(MaterialState.focused)
                ? CircleBorder(side: BorderSide(color: Colors.transparent))
                : CircleBorder(side: BorderSide(color: Colors.transparent))));

    ButtonStyle _gameStyle = ButtonStyle(
        maximumSize:
            MaterialStateProperty.resolveWith((states) => Size.fromWidth(460)),
        backgroundColor: MaterialStateProperty.resolveWith((state) =>
            state.contains(MaterialState.focused)
                ? Color(0xFFF2C416)
                : Colors.transparent),
        padding:
            MaterialStateProperty.resolveWith((state) => EdgeInsets.all(0)),
        shadowColor: MaterialStateProperty.resolveWith((state) =>
            state.contains(MaterialState.focused)
                ? Colors.black
                : Colors.transparent));

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background.png"),
            fit: BoxFit.fill,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              //////////////////////////////
              ///  TOP BAR WITH BUTTONS  ///
              //////////////////////////////
              Padding(padding: EdgeInsets.all(4)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  //DESKTOP
                  MyCustomButton(
                    child: Image(
                      image: AssetImage("assets/images/desktop.png"),
                      width: buttonWidth,
                      height: buttonWidth,
                    ),
                    style: _buttonStyle,
                    onPressed: () {
                      setPage("desktop");
                    },
                  ),
                  //GAMECUBE
                  MyCustomButton(
                    child: Image(
                      image: AssetImage("assets/images/gamecube.png"),
                      width: buttonWidth,
                      height: buttonWidth,
                    ),
                    style: _buttonStyle,
                    onPressed: () {
                      setPage("gamecube");
                    },
                  ),
                  //N64
                  MyCustomButton(
                    child: Image(
                      image: AssetImage("assets/images/n64.png"),
                      width: buttonWidth,
                      height: buttonWidth,
                    ),
                    style: _buttonStyle,
                    onPressed: () {
                      setPage("n64");
                    },
                  ),
                  //NES
                  MyCustomButton(
                    child: Image(
                      image: AssetImage("assets/images/nes.png"),
                      width: buttonWidth,
                      height: buttonWidth,
                    ),
                    style: _buttonStyle,
                    onPressed: () {
                      setPage("nes");
                    },
                  ),
                  //GBA
                  MyCustomButton(
                    child: Image(
                      image: AssetImage("assets/images/gba.png"),
                      width: buttonWidth,
                      height: buttonWidth,
                    ),
                    style: _buttonStyle,
                    onPressed: () {
                      setPage("gba");
                    },
                  ),
                  //ATARI
                  MyCustomButton(
                    child: Image(
                      image: AssetImage("assets/images/atari.png"),
                      width: buttonWidth,
                      height: buttonWidth,
                    ),
                    style: _buttonStyle,
                    onPressed: () {
                      setPage("atari");
                    },
                  ),
                  //SEGA
                  MyCustomButton(
                    child: Image(
                      image: AssetImage("assets/images/sega.png"),
                      height: buttonWidth,
                      width: buttonWidth,
                    ),
                    style: _buttonStyle,
                    onPressed: () {
                      setPage("sega");
                    },
                  ),
                  //APPLE
                  MyCustomButton(
                    child: Image(
                      image: AssetImage("assets/images/apple.png"),
                      height: buttonWidth,
                      width: buttonWidth,
                    ),
                    style: _buttonStyle,
                    onPressed: () {
                      setPage("apple");
                    },
                  ),
                  //SETTINGS
                  MyCustomButton(
                    focusNode: _focusNode,
                    child: Image(
                      image: AssetImage("assets/images/settings.png"),
                      height: buttonWidth,
                      width: buttonWidth,
                    ),
                    style: _buttonStyle,
                    onPressed: () {
                      setPage("settings");
                    },
                  ),
                ],
              ),
              Padding(padding: EdgeInsets.all(4)),
              //////////////////////////
              ///  SEARCH CONTAINER  ///
              //////////////////////////
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: <
                  Widget>[
                Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  decoration: BoxDecoration(
                    color: Color(0x77000000),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: EdgeInsets.fromLTRB(0, 8, 0, 0),
                  child: SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        for (String s in search)
                          MyCustomButton(
                            child: Text(
                              s,
                              style: TextStyle(
                                fontFamily: "Poppins-Semibold",
                                color: Colors.white,
                              ),
                            ),
                            style: selectedSearch == s
                                ? ButtonStyle(
                                    padding: MaterialStateProperty.resolveWith(
                                        (states) => EdgeInsets.all(15)),
                                    shape: MaterialStateProperty.resolveWith(
                                        (states) => CircleBorder(
                                            side: BorderSide(
                                                color: Colors.transparent))),
                                    backgroundColor:
                                        MaterialStateColor.resolveWith(
                                            (states) => Color(0x55ffffff)),
                                  )
                                : _searchStyle,
                            onPressed: () {
                              setState(() {
                                selectedSearch = s;
                              });
                              ((context) as Element).markNeedsBuild();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                /////////////////////////
                ///  GAMES CONTAINER  ///
                /////////////////////////
                Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  width: MediaQuery.of(context).size.width * 0.95,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                    border: Border.all(
                      style: BorderStyle.solid,
                      width: 10.0,
                      color: Color(0xFFF2C416),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(25, 20, 25, 0),
                  child: SingleChildScrollView(
                    child: showPage == "settings"
                        ? Column(
                            children: <Widget>[
                              Text(
                                "Settings",
                                style: TextStyle(
                                  fontFamily: "Poppins-Semibold",
                                  fontSize: 24,
                                ),
                              ),
                              Padding(padding: EdgeInsets.all(12)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    "Steam Path: ",
                                    style: TextStyle(
                                      fontFamily: "Poppins-Semibold",
                                    ),
                                  ),
                                  SizedBox(
                                    width: 300,
                                    height: 24,
                                    child: TextFormField(
                                        textAlignVertical:
                                            TextAlignVertical.top,
                                        initialValue:
                                            prefs.getString("SteamPath")!,
                                        minLines: 1),
                                  ),
                                  Padding(padding: EdgeInsets.all(12)),
                                  ElevatedButton(
                                    child: Image(
                                      image: AssetImage(
                                          "assets/images/folder.png"),
                                      width: 32,
                                      height: 32,
                                    ),
                                    onPressed: () async {
                                      String? result = await FilePicker.platform
                                          .getDirectoryPath();
                                      String path = result!;
                                      while (!(path.endsWith('SteamLibrary'))) {
                                        result = await FilePicker.platform
                                            .getDirectoryPath();
                                        path = result!;
                                      }
                                      prefs.setString("SteamPath",
                                          path.replaceAll("\\", "/"));
                                      reloadGames();
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                              Padding(padding: EdgeInsets.all(12)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    "ROM Path: ",
                                    style: TextStyle(
                                      fontFamily: "Poppins-Semibold",
                                    ),
                                  ),
                                  SizedBox(
                                    width: 300,
                                    height: 24,
                                    child: TextFormField(
                                        textAlignVertical:
                                            TextAlignVertical.top,
                                        initialValue:
                                            prefs.getString("RomsPath")!,
                                        minLines: 1),
                                  ),
                                  Padding(padding: EdgeInsets.all(12)),
                                  ElevatedButton(
                                    child: Image(
                                      image: AssetImage(
                                          "assets/images/folder.png"),
                                      width: 32,
                                      height: 32,
                                    ),
                                    onPressed: () async {
                                      String? result = await FilePicker.platform
                                          .getDirectoryPath();
                                      String path = result!;
                                      prefs.setString("RomsPath",
                                          path.replaceAll("\\", "/"));
                                      if (deskGames.isEmpty) {
                                        reloadGames();
                                      }
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          )
                        : GridView.count(
                            primary: true,
                            crossAxisCount: showPage == "desktop" ? 3 : 5,
                            shrinkWrap: true,
                            crossAxisSpacing: 120,
                            mainAxisSpacing: 20,
                            childAspectRatio: showPage == "desktop" ? 2 : 0.8,
                            children: <Widget>[
                              if (deskGames.isNotEmpty)
                                for (Game g in deskGames)
                                  if ((selectedSearch == "ALL" ||
                                          g.name.startsWith(selectedSearch)) &&
                                      g.cat == showPage)
                                    MyCustomButton(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                            MediaQuery.of(context).size.width *
                                                0.02),
                                        child: Image(
                                          image: g.icon.image,
                                        ),
                                      ),
                                      style: _gameStyle,
                                      onPressed: () async {
                                        if (g.cat == "desktop") {
                                          Process.start("cmd", [
                                            "cmd /c start steam://rungameid/${g.id}"
                                          ]);
                                        } else {
                                          OpenFile.open(
                                              "${prefs.getString("RomsPath")!.replaceAll("\\", "/")}/${g.name}");
                                        }
                                      },
                                    )
                            ],
                          ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/////////////////////////////
///  CUSTOM BUTTON CLASS  ///
/////////////////////////////
class MyCustomButton extends ElevatedButton {
  const MyCustomButton(
      {Key? key,
      required this.onPressed,
      required this.style,
      required this.child,
      FocusNode? focusNode})
      : super(
            key: key,
            onPressed: onPressed,
            autofocus: false,
            style: style,
            focusNode: focusNode,
            onLongPress: onPressed,
            child: child,
            clipBehavior: Clip.none);

  final Widget child;
  final VoidCallback onPressed;
  final ButtonStyle style;

  @override
  State<MyCustomButton> createState() => _MyCustomButtonState();
}

class _MyCustomButtonState extends State<MyCustomButton> {
  @override
  Widget build(BuildContext context) {
// Change visuals based on focus/hover state
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      enabled: false,
      // Hook up the built-in `ActivateIntent` to submit on [Enter] and [Space]
      onFocusChange: (value) {
        if (value) {
          setState(() {
            selectedButton = widget;
          });
        }
      },

      child: ElevatedButton(
          child: widget.child,
          style: widget.style,
          onPressed: widget.onPressed),
    );
  }
}
