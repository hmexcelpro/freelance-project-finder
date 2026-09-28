import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const supabaseUrl='https://illhoplnypumnvnkvavo.supabase.co';
const supabaseKey='sb_publishable_8rADrLEI5zrW2amgUZXhpg_R2EhOrQH';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url:supabaseUrl,anonKey:supabaseKey);
  runApp(const App());
}
final db=Supabase.instance.client;

class App extends StatelessWidget {
 const App({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(
   debugShowCheckedModeBanner:false,
   title:'Freelance Project Finder',
   theme:ThemeData(useMaterial3:true),
   home:StreamBuilder<AuthState>(
     stream:db.auth.onAuthStateChange,
     builder:(_,__)=>db.auth.currentSession==null
       ?const LoginPage():const HomePage(),
   ));
}

class LoginPage extends StatefulWidget {
 const LoginPage({super.key});
 @override State<LoginPage> createState()=>_LoginPageState();
}

class _LoginPageState extends State<LoginPage>{
 final email=TextEditingController(),pass=TextEditingController();
 bool busy=false;
 String? error;

 Future<void> login()async{
   setState(()=>busy=true);
   try{
     await db.auth.signInWithPassword(
       email:email.text.trim(),password:pass.text);
   }catch(e){
     setState(()=>error=e.toString());
   }finally{
     if(mounted)setState(()=>busy=false);
   }
 }

 Future<void> signup()async{
   setState(()=>busy=true);
   try{
     await db.auth.signUp(
       email:email.text.trim(),password:pass.text);
     if(mounted){
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content:Text('ایمیل تأیید را بررسی کنید.')));
     }
   }catch(e){
     setState(()=>error=e.toString());
   }finally{
     if(mounted)setState(()=>busy=false);
   }
 }

 @override
 Widget build(BuildContext c)=>Scaffold(
  body:SafeArea(
   child:Center(
    child:SingleChildScrollView(
     padding:const EdgeInsets.all(24),
     child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:420),
      child:Column(children:[
       const Icon(Icons.work_outline,size:72),
       const SizedBox(height:16),
       const Text('Freelance Project Finder',
         style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
       const SizedBox(height:28),
       TextField(
        controller:email,
        keyboardType:TextInputType.emailAddress,
        decoration:const InputDecoration(
          labelText:'ایمیل',border:OutlineInputBorder())),
       const SizedBox(height:12),
       TextField(
        controller:pass,
        obscureText:true,
        decoration:const InputDecoration(
          labelText:'رمز عبور',border:OutlineInputBorder())),
       if(error!=null)
        Padding(
         padding:const EdgeInsets.all(8),
         child:Text(error!,
           style:const TextStyle(color:Colors.red))),
       const SizedBox(height:16),
       SizedBox(
        width:double.infinity,
        child:FilledButton(
         onPressed:busy?null:login,
         child:Text(busy?'...':'ورود'))),
       TextButton(
        onPressed:busy?null:signup,
        child:const Text('ساخت حساب')),
      ]),
     ),
    ),
   ),
  ),
 );
}

class HomePage extends StatefulWidget {
 const HomePage({super.key});
 @override State<HomePage> createState()=>_HomePageState();
}

class _HomePageState extends State<HomePage>{
 int tab=0;

 @override
 Widget build(BuildContext c)=>Scaffold(
  appBar:AppBar(
   title:const Text('Freelance Project Finder'),
   actions:[
    IconButton(
     onPressed:()=>db.auth.signOut(),
     icon:const Icon(Icons.logout))
   ]),
  body:[
   const ProjectsPage(),
   const FiltersPage(),
   const SettingsPage()
  ][tab],
  bottomNavigationBar:NavigationBar(
   selectedIndex:tab,
   onDestinationSelected:(v)=>setState(()=>tab=v),
   destinations:const[
    NavigationDestination(
      icon:Icon(Icons.work_outline),label:'پروژه‌ها'),
    NavigationDestination(
      icon:Icon(Icons.tune),label:'فیلترها'),
    NavigationDestination(
      icon:Icon(Icons.settings_outlined),label:'تنظیمات')
   ]),
 );
}

class ProjectsPage extends StatefulWidget{
 const ProjectsPage({super.key});
 @override State<ProjectsPage> createState()=>_ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage>{
 Future<List<dynamic>> load()async=>
   await db.from('projects')
    .select('*,platforms(name)')
    .order('first_seen_at',ascending:false)
    .limit(100);

 Future<void> status(String id,String v)async{
   await db.from('projects').update({'status':v}).eq('id',id);
   setState((){});
 }

 @override
