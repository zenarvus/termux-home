package com.zenarvus.termuxhome;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;

public class MainActivity extends Activity {
    private Intent termuxIntent;

    private void launchTermux() {
        if (termuxIntent == null) {
            termuxIntent = getPackageManager().getLaunchIntentForPackage("com.termux");
		}
		startActivity(termuxIntent);
    }

    @Override
    public void onCreate(Bundle savedInstanceState){
		super.onCreate(savedInstanceState); launchTermux();
	}

	@Override
	public void onResume(){ super.onResume(); launchTermux(); }
}
