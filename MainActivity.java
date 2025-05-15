package com.example.notimemo;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;

import android.view.View;
import android.widget.Button;
import android.widget.EditText;

//메모 입력 및 Foreground Service 시작
public class MainActivity extends AppCompatActivity {

    private static final String CHANNEL_ID = "notimemo_channel";
    private static final String PREFS_NAME = "NotiMemoPrefs";
    private static final String MEMO_KEY = "saved_memo";

    private EditText memoInput;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // Android 13+ 알림 권한 요청
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this,
                        new String[]{android.Manifest.permission.POST_NOTIFICATIONS},
                        101);
            }
        }

        createNotificationChannel();

        memoInput = findViewById(R.id.memo_input);
        Button notifyBtn = findViewById(R.id.notify_button);

        // 앱 시작 시 저장된 메모 불러오기
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        String savedMemo = prefs.getString(MEMO_KEY, "");
        memoInput.setText(savedMemo);  // EditText에 표시

        // 버튼 클릭 시 메모 저장 + 알림 생성
        notifyBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                String memo = memoInput.getText().toString();

                // SharedPreferences에 저장
                SharedPreferences.Editor editor = getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit();
                editor.putString(MEMO_KEY, memo);
                editor.apply();

                // Foreground Service 시작
                Intent serviceIntent = new Intent(MainActivity.this, NotiMemoService.class);
                serviceIntent.putExtra("memo", memo);
                ContextCompat.startForegroundService(MainActivity.this, serviceIntent);

                // 알림 띄우기
                showNotification(memo);
            }
        });
    }

    private void showNotification(String message) {
        Intent intent = new Intent(this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);

        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notify_white)
                .setContentTitle("NotiMemo")
                .setContentText(message)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT);

        NotificationManager notificationManager = getSystemService(NotificationManager.class);
        notificationManager.notify(1, builder.build());
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            CharSequence name = "NotiMemo Channel";
            String description = "알림 고정용 채널";
            int importance = NotificationManager.IMPORTANCE_DEFAULT;
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, name, importance);
            channel.setDescription(description);

            NotificationManager notificationManager = getSystemService(NotificationManager.class);
            notificationManager.createNotificationChannel(channel);
        }
    }
}
