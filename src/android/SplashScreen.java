/*
       Licensed to the Apache Software Foundation (ASF) under one
       or more contributor license agreements.  See the NOTICE file
       distributed with this work for additional information
       regarding copyright ownership.  The ASF licenses this file
       to you under the Apache License, Version 2.0 (the
       "License"); you may not use this file except in compliance
       with the License.  You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

       Unless required by applicable law or agreed to in writing,
       software distributed under the License is distributed on an
       "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
       KIND, either express or implied.  See the License for the
       specific language governing permissions and limitations
       under the License.
 */

package org.apache.cordova.splashscreen;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.json.JSONArray;
import org.json.JSONException;

import android.app.Dialog;
import android.app.ProgressDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.content.res.Configuration;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.os.Environment;
import android.os.Handler;
import android.support.v4.view.PagerAdapter;
import android.support.v4.view.ViewPager;
import android.util.Log;
import android.view.Display;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup.LayoutParams;
import android.view.WindowManager;
import android.widget.ImageView;
import android.widget.LinearLayout;

public class SplashScreen extends CordovaPlugin {
	private static final String LOG_TAG = "SplashScreen";
	// Cordova 3.x.x has a copy of this plugin bundled with it
	// (SplashScreenInternal.java).
	// Enable functionality only if running on 4.x.x.
	private static final boolean HAS_BUILT_IN_SPLASH_SCREEN = Integer.valueOf(CordovaWebView.CORDOVA_VERSION.split("\\.")[0]) < 4;
	private Dialog splashDialog; // TODO: FUYH static been removed

	private ProgressDialog spinnerDialog; // TODO: FUYH static been removed
	private boolean firstShow = true; // TODO:FUYH

	/**
	 * Displays the splash drawable.
	 */
	private ImageView splashImageView;

	/**
	 * Remember last device orientation to detect orientation changes.
	 */
	private int orientation;

	/*** 图片文件储存位置 */
	private String savePath = Environment.getExternalStorageDirectory().getPath() + "/box/";

	private SharedPreferences boxPreferences;
	private Editor editor;

	private Dialog guideDialog;
	private List<View> guideViews = new ArrayList<View>();
	private ViewPager guidePager;

	// Helper to be compile-time compatible with both Cordova 3.x and 4.x.
	private View getView() {
		try {
			return (View) webView.getClass().getMethod("getView").invoke(webView);
		} catch (Exception e) {
			return (View) webView;
		}
	}

	@Override
	protected void pluginInitialize() {
		Log.i(LOG_TAG, "firstShow:" + firstShow);

		boxPreferences = cordova.getActivity().getSharedPreferences("box_data", Context.MODE_PRIVATE);
		editor = boxPreferences.edit();

		if (HAS_BUILT_IN_SPLASH_SCREEN || !firstShow) {
			return;
		}
		// Make WebView invisible while loading URL
		// getView().setVisibility(View.INVISIBLE); TODO:FUYH
		int drawableId = preferences.getInteger("SplashDrawableId", 0);
		if (drawableId == 0) {
			String splashResource = preferences.getString("SplashScreen", "screen");
			if (splashResource != null) {
				drawableId = cordova.getActivity().getResources().getIdentifier(splashResource, "drawable", cordova.getActivity().getClass().getPackage().getName());
				if (drawableId == 0) {
					drawableId = cordova.getActivity().getResources().getIdentifier(splashResource, "drawable", cordova.getActivity().getPackageName());
				}
				preferences.set("SplashDrawableId", drawableId);
			}
		}

		// Save initial orientation.
		orientation = cordova.getActivity().getResources().getConfiguration().orientation;

		firstShow = false;
		loadSpinner();

		Log.i(LOG_TAG, "pluginInitialized show");

		// TODO:FUYH no need for hide it because the launch-screen.js would hide
		// it
		// after Template.body.rendered
		showSplashScreen(false);

		saveImage();
	}

	/**
	 * Shorter way to check value of "SplashMaintainAspectRatio" preference.
	 */
	private boolean isMaintainAspectRatio() {
		return preferences.getBoolean("SplashMaintainAspectRatio", false);
	}

	@Override
	public void onPause(boolean multitasking) {
		if (HAS_BUILT_IN_SPLASH_SCREEN) {
			return;
		}
		// hide the splash screen to avoid leaking a window
		this.removeSplashScreen();
	}

	@Override
	public void onDestroy() {
		if (HAS_BUILT_IN_SPLASH_SCREEN) {
			return;
		}
		// hide the splash screen to avoid leaking a window
		this.removeSplashScreen();
		// If we set this to true onDestroy, we lose track when we go from page
		// to page!
		// firstShow = true;
	}

	@Override
	public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
		if (action.equals("hide")) {
			cordova.getActivity().runOnUiThread(new Runnable() {
				public void run() {
					webView.postMessage("splashscreen", "hide");
				}
			});
		} else if (action.equals("show")) {
			cordova.getActivity().runOnUiThread(new Runnable() {
				public void run() {
					webView.postMessage("splashscreen", "show");
				}
			});
		} else if (action.equals("spinnerStart")) {
			if (!HAS_BUILT_IN_SPLASH_SCREEN) {
				final String title = args.getString(0);
				final String message = args.getString(1);
				cordova.getActivity().runOnUiThread(new Runnable() {
					public void run() {
						spinnerStart(title, message);
					}
				});
			}
		} else {
			return false;
		}

		callbackContext.success();
		return true;
	}

	@Override
	public Object onMessage(String id, Object data) {
		if (HAS_BUILT_IN_SPLASH_SCREEN) {
			return null;
		}
		if ("splashscreen".equals(id)) {

			Log.i(LOG_TAG, data.toString());

			if ("hide".equals(data.toString())) {
				this.removeSplashScreen();
			} else {
				this.showSplashScreen(false);
			}
		} else if ("spinner".equals(id)) {
			if ("stop".equals(data.toString())) {
				this.spinnerStop();
				getView().setVisibility(View.VISIBLE);
			}
		} else if ("onReceivedError".equals(id)) {
			spinnerStop();
		}
		return null;
	}

	// Don't add @Override so that plugin still compiles on 3.x.x for a while
	public void onConfigurationChanged(Configuration newConfig) {
		if (newConfig.orientation != orientation) {
			orientation = newConfig.orientation;

			// Splash drawable may change with orientation, so reload it.
			if (splashImageView != null) {
				int drawableId = preferences.getInteger("SplashDrawableId", 0);
				if (drawableId != 0) {
					splashImageView.setImageDrawable(cordova.getActivity().getResources().getDrawable(drawableId));
				}
			}
		}
	}

	private void removeSplashScreen() {
		cordova.getActivity().runOnUiThread(new Runnable() {
			public void run() {
				if (splashDialog != null && splashDialog.isShowing()) {

					// splashDialog.dismiss();
					// splashDialog = null;
					// splashImageView = null;

					Display display = cordova.getActivity().getWindowManager().getDefaultDisplay();
					Context context = webView.getContext();
					guidePager = new ViewPager(context);
					LayoutParams layoutParams = new LayoutParams(display.getWidth(), display.getHeight());

					String[] urlPaths = { "http://img5.duitang.com/uploads/item/201206/06/20120606175141_5vAs2.thumb.700_0.jpeg",
							"http://image.tianjimedia.com/uploadImages/2014/247/37/GTDCF51UT479_1000x500.jpg", "http://image.tianjimedia.com/uploadImages/2012/265/6Z25XW17035N.jpg",
							"http://static12.photo.sina.com.cn/middle/001ozpVvgy6GHWL7nrd2b&690.png", "http://static16.photo.sina.com.cn/middle/001ozpVvgy6GHWLgLkr9f&690.png",
							"http://static6.photo.sina.com.cn/middle/001ozpVvgy6GHWLc78V55&690.png" };

					for (int i = 0; i < urlPaths.length; i++) {

						String filePath = savePath + convertUrlToFileName(urlPaths[i]);

						ImageView imageView = new ImageView(context);

						imageView.setImageBitmap(BitmapFactory.decodeFile(filePath));
						if (isMaintainAspectRatio()) {
							imageView.setScaleType(ImageView.ScaleType.CENTER_CROP);
						} else {
							imageView.setScaleType(ImageView.ScaleType.FIT_XY);
						}

						imageView.setLayoutParams(layoutParams);

						if (i == urlPaths.length - 1) {

							imageView.setOnClickListener(new OnClickListener() {

								@Override
								public void onClick(View v) {

									splashDialog.dismiss();
									splashDialog = null;
									splashImageView = null;

									guideDialog.dismiss();
									guideDialog = null;
									guidePager = null;

								}
							});
						}
						guideViews.add(imageView);
					}

					guidePager.setAdapter(new PagerAdapter() {

						// 销毁arg1位置的界面
						@Override
						public void destroyItem(View arg0, int arg1, Object arg2) {
							((ViewPager) arg0).removeView(guideViews.get(arg1));
						}

						// 获得当前界面数
						@Override
						public int getCount() {
							if (guideViews != null) {
								return guideViews.size();
							}

							return 0;
						}

						// 初始化arg1位置的界面
						@Override
						public Object instantiateItem(View arg0, int arg1) {

							((ViewPager) arg0).addView(guideViews.get(arg1), 0);

							return guideViews.get(arg1);
						}

						// 判断是否由对象生成界面
						@Override
						public boolean isViewFromObject(View arg0, Object arg1) {
							return (arg0 == arg1);
						}

					});

					guideDialog = new Dialog(context, android.R.style.Theme_Translucent_NoTitleBar);
					// check to see if the splash screen should be full screen
					if ((cordova.getActivity().getWindow().getAttributes().flags & WindowManager.LayoutParams.FLAG_FULLSCREEN) == WindowManager.LayoutParams.FLAG_FULLSCREEN) {
						splashDialog.getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);
					}
					guideDialog.setContentView(guidePager);
					guideDialog.setCancelable(false);
					guideDialog.show();

				}
			}
		});
	}

	/**
	 * Shows the splash screen over the full Activity
	 */
	@SuppressWarnings("deprecation")
	private void showSplashScreen(final boolean hideAfterDelay) {
		final int splashscreenTime = preferences.getInteger("SplashScreenDelay", 3000);
		final int drawableId = preferences.getInteger("SplashDrawableId", 0);

		// If the splash dialog is showing don't try to show it again
		if (splashDialog != null && splashDialog.isShowing()) {
			return;
		}
		if (drawableId == 0 || (splashscreenTime <= 0 && hideAfterDelay)) {
			return;
		}

		cordova.getActivity().runOnUiThread(new Runnable() {
			public void run() {
				// Get reference to display
				Display display = cordova.getActivity().getWindowManager().getDefaultDisplay();
				Context context = webView.getContext();

				// Use an ImageView to render the image because of its flexible
				// scaling options.
				splashImageView = new ImageView(context);

				String filePath = boxPreferences.getString("filePath", null);
				if (null != BitmapFactory.decodeFile(filePath)) {
					splashImageView.setImageBitmap(BitmapFactory.decodeFile(filePath));
				} else {
					splashImageView.setImageResource(drawableId);
				}

				LayoutParams layoutParams = new LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT);
				splashImageView.setLayoutParams(layoutParams);

				splashImageView.setMinimumHeight(display.getHeight());
				splashImageView.setMinimumWidth(display.getWidth());

				// TODO: Use the background color of the webView's parent
				// instead of using the preference.
				splashImageView.setBackgroundColor(preferences.getInteger("backgroundColor", Color.BLACK));

				if (isMaintainAspectRatio()) {
					// CENTER_CROP scale mode is equivalent to CSS
					// "background-size:cover"
					splashImageView.setScaleType(ImageView.ScaleType.CENTER_CROP);
				} else {
					// FIT_XY scales image non-uniformly to fit into image view.
					splashImageView.setScaleType(ImageView.ScaleType.FIT_XY);
				}

				// Create and show the dialog
				splashDialog = new Dialog(context, android.R.style.Theme_Translucent_NoTitleBar);
				// check to see if the splash screen should be full screen
				if ((cordova.getActivity().getWindow().getAttributes().flags & WindowManager.LayoutParams.FLAG_FULLSCREEN) == WindowManager.LayoutParams.FLAG_FULLSCREEN) {
					splashDialog.getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);
				}
				splashDialog.setContentView(splashImageView);
				splashDialog.setCancelable(false);
				splashDialog.show();

				// Set Runnable to remove splash screen just in case
				if (hideAfterDelay) {
					final Handler handler = new Handler();
					handler.postDelayed(new Runnable() {
						public void run() {
							removeSplashScreen();
						}
					}, splashscreenTime);
				}
			}
		});
	}

	/*
	 * Load the spinner
	 */
	private void loadSpinner() {
		// If loadingDialog property, then show the App loading dialog for first
		// page of app
		String loading = null;
		if (webView.canGoBack()) {
			loading = preferences.getString("LoadingDialog", null);
		} else {
			loading = preferences.getString("LoadingPageDialog", null);
		}
		if (loading != null) {
			String title = "";
			String message = "Loading Application...";

			if (loading.length() > 0) {
				int comma = loading.indexOf(',');
				if (comma > 0) {
					title = loading.substring(0, comma);
					message = loading.substring(comma + 1);
				} else {
					title = "";
					message = loading;
				}
			}
			spinnerStart(title, message);
		}
	}

	private void spinnerStart(final String title, final String message) {
		cordova.getActivity().runOnUiThread(new Runnable() {
			public void run() {
				spinnerStop();
				spinnerDialog = ProgressDialog.show(webView.getContext(), title, message, true, true, new DialogInterface.OnCancelListener() {
					public void onCancel(DialogInterface dialog) {
						spinnerDialog = null;
					}
				});
			}
		});
	}

	private void spinnerStop() {
		cordova.getActivity().runOnUiThread(new Runnable() {
			public void run() {
				if (spinnerDialog != null && spinnerDialog.isShowing()) {
					spinnerDialog.dismiss();
					spinnerDialog = null;
				}
			}
		});
	}

	/**
	 * 
	 * 储存广告图片至本地
	 */
	private void saveImage() {

		// 开启子线程，缓存广告图片存储本地，方便下次启动使用新广告图
		new Thread() {
			public void run() {
				try {

					File file = new File(savePath);
					if (!file.exists()) {
						file.mkdir();
					}

					String[] urlPaths = { "http://img5.duitang.com/uploads/item/201206/06/20120606175141_5vAs2.thumb.700_0.jpeg",
							"http://image.tianjimedia.com/uploadImages/2014/247/37/GTDCF51UT479_1000x500.jpg", "http://image.tianjimedia.com/uploadImages/2012/265/6Z25XW17035N.jpg",
							"http://static12.photo.sina.com.cn/middle/001ozpVvgy6GHWL7nrd2b&690.png", "http://static16.photo.sina.com.cn/middle/001ozpVvgy6GHWLgLkr9f&690.png",
							"http://static6.photo.sina.com.cn/middle/001ozpVvgy6GHWLc78V55&690.png" };

					String splashUrl = urlPaths[(int) (Math.random() * urlPaths.length)];

					String filePath = savePath + convertUrlToFileName(splashUrl);

					File saveFile = new File(filePath);
					if (!saveFile.exists()) {

						URL url = new URL(splashUrl);
						HttpURLConnection conn = (HttpURLConnection) url.openConnection();
						conn.setConnectTimeout(6 * 1000); // 注意要设置超时，设置时间不要超过10秒，避免被android系统回收

						if (conn.getResponseCode() != 200) {
							throw new RuntimeException("请求url失败");
						}

						InputStream inSream = conn.getInputStream();

						// 把图片保存到指定目录
						readAsFile(inSream, new File(filePath));

					}

					editor.putString("filePath", filePath);
					editor.commit();

				} catch (Exception e) {
					e.printStackTrace();
				}
			};
		}.start();
	}

	/**
	 * 储存文件
	 */
	private void readAsFile(InputStream inSream, File file) throws Exception {
		FileOutputStream outStream = new FileOutputStream(file);
		byte[] buffer = new byte[1024];
		int len = -1;
		while ((len = inSream.read(buffer)) != -1) {
			outStream.write(buffer, 0, len);
		}
		outStream.close();
		inSream.close();
	}

	/**
	 * 从图片路径中获取图片名
	 * 
	 * @param url
	 */
	private String convertUrlToFileName(String url) {
		String name = "";
		if (url != null && !"".equals(url)) {
			name = url.substring(url.lastIndexOf("/") + 1, url.length());
		}
		return name;
	}

}
