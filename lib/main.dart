import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:baseproj/api/messaging.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baby Names',
      theme: ThemeData(primaryColor: Colors.white),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() {
    return _MyHomePageState();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final db = Firestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  @override
  void initState() {
    super.initState();

    _firebaseMessaging.onTokenRefresh.listen(sendTokenToServer);
    _firebaseMessaging.getToken();

    _firebaseMessaging.subscribeToTopic('all');

    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        print("onMessage: $message");
        Scaffold.of(context).showSnackBar(SnackBar(
            content: Text('$message'), duration: Duration(milliseconds: 700)));
      },
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
        Scaffold.of(context).showSnackBar(SnackBar(
            content: Text('$message'), duration: Duration(milliseconds: 700)));
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");
      },
    );
    _firebaseMessaging.requestNotificationPermissions(
        const IosNotificationSettings(sound: true, badge: true, alert: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Emilist',
          style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0.0,
      ),
      body: _buildBody(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {
              _displayDialog(context);
            }),
        child: Icon(Icons.add),
        backgroundColor: Colors.white,
        foregroundColor: Colors.red,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _pushSaved() {}

  Widget _buildBody(BuildContext context) {
    return new Container(
      decoration: new BoxDecoration(
          // gradient: LinearGradient(
          //   // Where the linear gradient begins and ends
          //   begin: Alignment.topRight,
          //   end: Alignment.bottomLeft,
          //   // Add one stop for each color. Stops should increase from 0 to 1
          //   stops: [0.1, 0.9],
          //   colors: [
          //     // Colors are easy thanks to Flutter's Colors class.
          //     Colors.orange[600],
          //     Colors.red[500],
          //   ],
          // ),
          color: Colors.grey[100]),
      child: StreamBuilder<QuerySnapshot>(
        stream: db.collection('items').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return LinearProgressIndicator();

          return _buildList(context, snapshot.data.documents);
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, List<DocumentSnapshot> snapshot) {
    return ListView(
      padding: const EdgeInsets.only(top: 20.0),
      children: snapshot.map((data) => _buildListItem(context, data)).toList(),
    );
  }

  Widget _buildListItem(BuildContext context, DocumentSnapshot data) {
    final record = Record.fromSnapshot(data);
    final _toDoFont = TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold);
    final _doneFont = TextStyle(
        fontSize: 18.0,
        fontWeight: FontWeight.bold,
        decoration: TextDecoration.lineThrough,
        decorationThickness: 2.0);

    return Dismissible(
      // Each Dismissible must contain a Key. Keys allow Flutter to
      // uniquely identify widgets.
      key: Key(record.text),
      // Provide a function that tells the app
      // what to do after an item has been swiped away.
      onDismissed: (direction) {
        // Remove the item from the data source.
        record.reference.delete().whenComplete(() {
          setState(() {});
        });

        // Show a snackbar. This snackbar could also contain "Undo" actions.
        Scaffold.of(context).showSnackBar(SnackBar(
            content: Text('"${record.text}" deleted'),
            duration: Duration(milliseconds: 700)));
      },
      child: Container(
        margin: new EdgeInsets.only(bottom: 10.0, left: 16.0, right: 16.0),
        decoration: new BoxDecoration(
            //   boxShadow: [
            //     new BoxShadow(
            //       color: Colors.black,
            //       offset: new Offset(0.0, -1.0),
            //       blurRadius: 20.0,
            //       spreadRadius: -20.0,
            //     )
            //   ],
            color: Colors.white,
            borderRadius: new BorderRadius.all(Radius.circular(5.0))),
        child: Padding(
          key: ValueKey(record.text),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Container(
            child: ListTile(
              title: Text(
                record.text,
                style: record.completed ? _doneFont : _toDoFont,
              ),
              trailing: Icon(
                record.completed
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: record.completed ? Colors.red : null,
                size: 28.0,
              ),
              onTap: () {
                if (record.completed) {
                  record.reference.updateData({'completed': false});
                } else {
                  record.reference.updateData({'completed': true});
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  TextEditingController _textFieldController = TextEditingController();

  _displayDialog(BuildContext context) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Add List Item'),
            content: TextField(
              controller: _textFieldController,
              decoration: InputDecoration(hintText: "Name"),
            ),
            actions: <Widget>[
              new FlatButton(
                child: new Text('ADD'),
                onPressed: () {
                  Navigator.of(context).pop();
                  print(_textFieldController.text);
                  db.collection('items').add({
                    "text": _textFieldController.text,
                    "completed": false,
                    "timestamp": new DateTime.now()
                  });
                  sendNotification('New item added!',
                      '"${_textFieldController.text}" was added to the list!');
                  _textFieldController.text = "";
                },
              )
            ],
          );
        });
  }

  Future sendNotification(String title, String body) async {
    final response = await Messaging.sendToAll(
      title: title,
      body: body,
      // fcmToken: fcmToken,
    );

    if (response.statusCode != 200) {
      Scaffold.of(context).showSnackBar(SnackBar(
        content:
            Text('[${response.statusCode}] Error message: ${response.body}'),
      ));
    }
  }

  void sendTokenToServer(String fcmToken) {
    print('Token: $fcmToken');
    // send key to your server to allow server to use
    // this token to send push notifications
  }
}

class Record {
  final String text;
  final bool completed;
  final DocumentReference reference;

  Record.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['text'] != null),
        assert(map['completed'] != null),
        text = map['text'],
        completed = map['completed'];

  Record.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot.data, reference: snapshot.reference);

  @override
  String toString() => "Record<$text:$completed>";
}