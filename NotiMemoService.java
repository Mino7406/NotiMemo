package com.example.notimemo;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;

// Foreground Service: 앱이 종료되어도 알림을 계속 유지하기 위한 서비스 클래스
public class NotiMemoService extends Service {

    private static final String CHANNEL_ID = "notimemo_channel"; // 알림 채널 ID

    // 서비스가 시작될 때 호출되는 함수
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // 메모 내용 전달받기
        String memo = intent.getStringExtra("memo");

        // 알림 채널 만들기 (API 26+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "NotiMemo Channel",
                    NotificationManager.IMPORTANCE_DEFAULT
            );
            channel.setDescription("메모 고정 알림");

            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }

        // 알림 구성
        Notification notification = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("NotiMemo")
                .setContentText(memo != null ? memo : "메모 없음")
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setOngoing(true)
                .build();

        // Foreground Service 시작
        startForeground(1, notification);

        // 시스템이 종료해도 자동 재시작
        return START_STICKY;
    }
    // 바인딩 기능은 사용하지 않음.
    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}