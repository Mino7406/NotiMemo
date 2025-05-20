package com.example.notimemo;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Bundle;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;

import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import android.Manifest;
import android.content.pm.PackageManager;
import android.graphics.Color;

import androidx.appcompat.app.AlertDialog;

import org.json.JSONArray;
import org.json.JSONException;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends AppCompatActivity {

    private static final String CHANNEL_ID = "notimemo_channel";
    private static final String PREFS_NAME = "NotiMemoPrefs";
    private static final String MEMO_KEY = "saved_memo";
    private static final String MEMO_LIST_KEY = "memo_list";

    private EditText memoInput;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // Android 13 이상에서 알림 권한 요청
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this,
                        new String[]{Manifest.permission.POST_NOTIFICATIONS},
                        101);
            }
        }

        // UI 요소 초기화
        memoInput = findViewById(R.id.memo_input);
        Button notifyBtn = findViewById(R.id.notify_button);
        Button btnViewMemo = findViewById(R.id.btn_view_memo);

        // 앱 실행 시 저장된 메모 복원
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        String savedMemo = prefs.getString(MEMO_KEY, "");
        memoInput.setText(savedMemo);

        // 알림 생성 및 메모 저장 버튼 클릭 처리
        notifyBtn.setOnClickListener(view -> {
            String memo = memoInput.getText().toString();

            // 가장 최근 메모 저장
            SharedPreferences.Editor editor = getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit();
            editor.putString(MEMO_KEY, memo);
            editor.apply();

            // 메모 리스트에 새 항목 추가
            try {
                String oldJson = prefs.getString(MEMO_LIST_KEY, "[]");
                JSONArray array = new JSONArray(oldJson);
                array.put(memo);
                editor.putString(MEMO_LIST_KEY, array.toString());
                editor.apply();
            } catch (JSONException e) {
                e.printStackTrace();
            }

            // 알림 채널 생성 및 고정 알림 생성
            createNotificationChannel();

            // 알림 클릭 시 다시 앱으로 돌아오는 설정
            Intent intent = new Intent(this, MainActivity.class);
            PendingIntent pendingIntent = PendingIntent.getActivity(
                    this, 0, intent, PendingIntent.FLAG_IMMUTABLE);

            // 알림 빌더 설정
            NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                    .setSmallIcon(R.drawable.ic_notify_white)
                    .setContentTitle("고정된 메모")
                    .setContentText(memo)
                    .setContentIntent(pendingIntent)
                    .setOngoing(true)
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT);

            NotificationManager notificationManager = getSystemService(NotificationManager.class);
            notificationManager.notify(1, builder.build());

            // 사용자에게 고정 안내 토스트 출력
            Toast toast = Toast.makeText(getApplicationContext(), "메모 고정.", Toast.LENGTH_SHORT);
            View toastView = toast.getView();
            if (toastView != null) {
                toastView.setBackground(ContextCompat.getDrawable(this, R.drawable.toast_background));
                TextView text = toastView.findViewById(android.R.id.message);
                text.setTextColor(Color.WHITE);
                text.setPadding(32, 16, 32, 16);
                text.setTextSize(14);
            }
            toast.setGravity(Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL, 0, 200);
            toast.show();
        });

        // 고정된 메모 내역 보기 버튼 클릭 처리
        btnViewMemo.setOnClickListener(view -> {
            SharedPreferences preferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
            String memoJson = preferences.getString(MEMO_LIST_KEY, "[]");

            try {
                JSONArray jsonArray = new JSONArray(memoJson);
                ArrayList<String> memoList = new ArrayList<>();
                for (int i = 0; i < jsonArray.length(); i++) {
                    memoList.add(jsonArray.getString(i));
                }

                // 다이얼로그 생성
                AlertDialog.Builder builder = new AlertDialog.Builder(this);
                LinearLayout container = new LinearLayout(this);
                container.setOrientation(LinearLayout.VERTICAL);

                // 리스트 항목 UI 그리기
                redrawMemoList(memoList, container);

                // 전체 삭제 버튼 추가
                Button resetBtn = new Button(this);
                resetBtn.setText("전체 삭제");
                resetBtn.setOnClickListener(v -> {
                    memoList.clear();
                    saveMemoList(memoList);
                    Toast.makeText(this, "삭제 완료.", Toast.LENGTH_SHORT).show();
                    container.removeAllViews();
                    redrawMemoList(memoList, container);
                });

                container.addView(resetBtn);
                builder.setView(container);
                builder.setPositiveButton("닫기", null);
                builder.show();

            } catch (JSONException e) {
                e.printStackTrace();
            }
        });
    }

    // 메모 항목 리스트 다시 그리는 메서드
    private void redrawMemoList(List<String> memoList, LinearLayout container) {
        container.removeAllViews();

        for (int i = 0; i < memoList.size(); i++) {
            final int index = i;
            String memo = memoList.get(index);

            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setPadding(30, 30, 30, 30);

            TextView textView = new TextView(this);
            textView.setText("•   " + memo);
            textView.setTextSize(18);
            textView.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));

            ImageButton deleteBtn = new ImageButton(this);
            deleteBtn.setImageResource(R.drawable.ic_delete);
            deleteBtn.setBackground(null);

            // X 버튼 눌렀을 때 해당 항목 삭제
            deleteBtn.setOnClickListener(v -> {
                memoList.remove(index);
                saveMemoList(memoList);
                Toast.makeText(this, "삭제 완료.", Toast.LENGTH_SHORT).show();
                redrawMemoList(memoList, container);
            });

            row.addView(textView);
            row.addView(deleteBtn);
            container.addView(row);
        }
    }

    // 메모 리스트를 SharedPreferences에 저장
    private void saveMemoList(List<String> memoList) {
        JSONArray array = new JSONArray();
        for (String memo : memoList) {
            array.put(memo);
        }
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit()
                .putString(MEMO_LIST_KEY, array.toString())
                .apply();
    }

    // 알림 채널 생성 (Android 8.0 이상 필요)
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "NotiMemo Channel",
                    NotificationManager.IMPORTANCE_DEFAULT
            );
            channel.setDescription("고정 메모용 채널");

            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }
}
