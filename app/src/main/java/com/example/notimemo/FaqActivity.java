package com.example.notimemo;

import android.os.Bundle;
import androidx.appcompat.app.AppCompatActivity;

/**
 * 이파일은 앱의 FAQ 화면을 담당하는 액티비티.
 * 사용자가 도움말이나 정보를 확인할 수 있는 UI를 구성함.
 */
public class FaqActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // activity_faq.xml 레이아웃을 이 액티비티에 설정
        setContentView(R.layout.faq_activity);

    }
}
