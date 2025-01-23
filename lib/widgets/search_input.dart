import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SearchInput extends StatelessWidget {
  const SearchInput({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: Center(
        child: Container(
          width: 250,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: AppColors.primaryBackground,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryText.withOpacity(0.1),
                blurRadius: 3,
                offset: const Offset(1.5, 1.5),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.25),
                blurRadius: 3,
                offset: const Offset(-1.5, -1.5),
              ),
            ],
          ),
          child: Stack(
            children: [
              TextField(
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: "Type to search...",
                  hintStyle: const TextStyle(
                    color: AppColors.secondaryText,
                  ),
                  filled: true,
                  fillColor: AppColors.primaryBackground,
                  contentPadding: const EdgeInsets.only(left: 50),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide.none,
                  ),
                ),
                cursorColor: AppColors.primaryColor,
              ),
              Positioned(
                left: 0,
                top: 5,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.search,
                    color: AppColors.primaryText,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
