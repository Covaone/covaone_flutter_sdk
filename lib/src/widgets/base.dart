import 'package:flutter/material.dart';
import 'package:covaone_sdk/src/common/textstyles.dart';
import 'package:covaone_sdk/src/services/hex.dart';

import 'common/button.dart';

class BaseHomeScreen extends StatefulWidget {
  const BaseHomeScreen({Key? key}) : super(key: key);

  @override
  State<BaseHomeScreen> createState() => _BaseHomeScreenState();
}

class _BaseHomeScreenState extends State<BaseHomeScreen> with AppResouces {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 390,
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 26, horizontal: 17),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor.withValues(alpha: .8),
                      // primaryColor.withOpacity(.8),
                      primaryColor,
                    ],
                    stops: const [0, 0.65],
                  ),
                  // boxShadow: [
                  //   BoxShadow(
                  //     color: primaryColor.withOpacity(.4),
                  //     blurRadius: 25.0, // soften the shadow
                  //     spreadRadius: 20.0, //extend the shadow
                  //     offset: const Offset(
                  //       0.0,
                  //       100.0,
                  //     ),
                  //   )
                  // ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                height: 20,
                              ),
                              Text('Hey There 👋,\nHow can we help you',
                                  style: kHeaderText.copyWith(
                                    color: Colors.white,
                                  )),
                              const SizedBox(
                                height: 10,
                              ),
                              Text(
                                'Help & Chat Support',
                                style: kDefault.copyWith(
                                    color: const Color(0xFFBBBBBB),
                                    fontSize: 18,
                                    height: 1),
                              ),
                              const SizedBox(
                                height: 8,
                              ),
                              Text(
                                'Typically replies instantly.',
                                style: kDefault.copyWith(
                                    color: const Color(0xFFBBBBBB),
                                    fontSize: 13,
                                    height: 1),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          child: Container(
                            height: 70,
                            width: 70,
                            decoration: BoxDecoration(
                                color: const Color(0xFFF4CE9B),
                                borderRadius: BorderRadius.circular(50),
                                border:
                                    Border.all(color: Colors.white, width: 2)),
                            child: Image.asset(
                              'assets/file/tola.jpeg',
                              package: 'covaone_sdk',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 60,
                    ),
                    Row(
                      children: [
                        AppButton(
                            text: 'Send a Message',
                            cta: () => null,
                            height: 52,
                            backgroundColor: Colors.white,
                            textColor: Colors.black,
                            radius: 14)
                      ],
                    ),
                    // Row(
                    //   children: [
                    //     Column(
                    //       children: [
                    //         Expanded(
                    //           child: Container(
                    //             height: 200,
                    //             width: double.infinity,
                    //           ),
                    //         )
                    //       ],
                    //     )
                    //   ],
                    // )
                  ],
                ),
              ),
              // Container(
              //   height: 50,
              //   margin: EdgeInsets.only(top: 390),
              //   decoration: BoxDecoration(
              //     gradient: LinearGradient(
              //       begin: Alignment.topCenter,
              //       end: Alignment.bottomRight,
              //       colors: [
              //         primaryColor,
              //         primaryColor.withOpacity(.8),
              //       ],
              //       stops: [0, 0.97],
              //     ),
              //   ),
              // ),
              Container(
                margin: const EdgeInsets.only(top: 300),
                height: 500,
                width: double.infinity,
                decoration: const BoxDecoration(color: Colors.transparent),
                child: Column(
                  children: [
                    Container(
                      height: 270,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 17),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(40, 40, 40, .16),
                            blurRadius: 10.0, // soften the shadow
                            spreadRadius: 3.0, //extend the shadow
                            offset: Offset(
                              0.0,
                              0.0,
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
