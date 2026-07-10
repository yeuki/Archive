package com.kyle.archive;

import android.os.Bundle;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(ConnectedHealthPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
