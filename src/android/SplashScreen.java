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
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.pm.PackageManager.NameNotFoundException;
import android.content.res.Configuration;
import android.graphics.Bitmap;
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

	private Display display;
	private Context context;

	/*** 图片文件储存位置 */
	private String savePath = Environment.getExternalStorageDirectory().getPath() + "/box/";

	private SharedPreferences boxPreferences;
	private Editor editor;

	private Dialog mGuideDialog; // 引导页面显示容器
	private List<View> mGuideViews; // 引导页内容list
	private ViewPager mGuidePager; // 引导页面控制控件

	private Object[] testGuidePaths = { "http://img5.duitang.com/uploads/item/201206/06/20120606175141_5vAs2.thumb.700_0.jpeg", "http://image.tianjimedia.com/uploadImages/2012/265/6Z25XW17035N.jpg",
			"http://static12.photo.sina.com.cn/middle/001ozpVvgy6GHWL7nrd2b&690.png", "http://static16.photo.sina.com.cn/middle/001ozpVvgy6GHWLgLkr9f&690.png",
			"http://static6.photo.sina.com.cn/middle/001ozpVvgy6GHWLc78V55&690.png" };

	private String testSplash = "http://image.tianjimedia.com/uploadImages/2014/247/37/GTDCF51UT479_1000x500.jpg";

	String GUIDEPAGEINFOURL;
	String LOADPAGEINFOURL;
	int GUIDEIMAGECOUNT;

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

		display = cordova.getActivity().getWindowManager().getDefaultDisplay();
		context = webView.getContext();

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

		ActivityInfo info;
		try {
			info = cordova.getActivity().getPackageManager().getActivityInfo(cordova.getActivity().getComponentName(), PackageManager.GET_META_DATA);
			GUIDEPAGEINFOURL = info.applicationInfo.metaData.getString("GUIDEPAGEINFOURL");
			LOADPAGEINFOURL = info.applicationInfo.metaData.getString("LOADPAGEINFOURL");
			GUIDEIMAGECOUNT = info.applicationInfo.metaData.getInt("GUIDEIMAGECOUNT", 0);

		} catch (NameNotFoundException e) {
			e.printStackTrace();
		}

		saveImage(testSplash, true);

		for (int i = 0; i < testGuidePaths.length; i++) {
			saveImage(testGuidePaths[i], false);
		}
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
				if (splashDialog != null && splashDialog.isShowing() && null == mGuideDialog) {

					final Boolean isFirst = boxPreferences.getBoolean("isFirst", true);
					final Boolean show = boxPreferences.getBoolean("show", false);

					if (isFirst) {

						mGuidePager = new ViewPager(context);
						mGuideViews = new ArrayList<View>();
						LayoutParams layoutParams = new LayoutParams(display.getWidth(), display.getHeight());
						ImageView imageView;
						String filePath;

						final Boolean isComplete = isComplete(testGuidePaths);

						if (isComplete && show) {

						} else {
							testGuidePaths = new Object[3];
							testGuidePaths[0] = cordova.getActivity().getResources().getIdentifier("guide_1", "drawable", cordova.getActivity().getClass().getPackage().getName());
							testGuidePaths[1] = cordova.getActivity().getResources().getIdentifier("guide_2", "drawable", cordova.getActivity().getClass().getPackage().getName());
							testGuidePaths[2] = cordova.getActivity().getResources().getIdentifier("guide_3", "drawable", cordova.getActivity().getClass().getPackage().getName());

						}

						for (int i = 0; i < testGuidePaths.length; i++) {

							imageView = new ImageView(context);

							if (isComplete && show) {
								filePath = savePath + convertUrlToFileName(testGuidePaths[i]);
								imageView.setImageBitmap(BitmapFactory.decodeFile(filePath));
							} else {
								imageView.setImageResource((Integer) testGuidePaths[i]);
							}

							imageView.setScaleType(ImageView.ScaleType.CENTER_CROP);
							imageView.setLayoutParams(layoutParams);

							if (i == testGuidePaths.length - 1) {

								imageView.setOnClickListener(new OnClickListener() {

									@Override
									public void onClick(View v) {

										mGuideDialog.dismiss();
										mGuideDialog = null;
										mGuidePager = null;

										splashDialog.dismiss();
										splashDialog = null;
										splashImageView = null;

										editor.putBoolean("show", true);
										editor.commit();

										if (isComplete && show) {

											editor.putBoolean("isFirst", false);
											editor.commit();

											editor.putBoolean("show", false);
											editor.commit();
										}
									}
								});
							}
							mGuideViews.add(imageView);
						}

						mGuidePager.setAdapter(new guideAdapter());

						mGuideDialog = new Dialog(context, android.R.style.Theme_Translucent_NoTitleBar);
						// check to see if the splash screen should be full
						// screen
						if ((cordova.getActivity().getWindow().getAttributes().flags & WindowManager.LayoutParams.FLAG_FULLSCREEN) == WindowManager.LayoutParams.FLAG_FULLSCREEN) {
							splashDialog.getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);
						}
						mGuideDialog.setContentView(mGuidePager);
						mGuideDialog.setCancelable(false);
						mGuideDialog.show();

					} else {

						splashDialog.dismiss();
						splashDialog = null;
						splashImageView = null;

					}

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
	 * 引导页viewpager适配器
	 * 
	 * @author SunX
	 * 
	 */
	private class guideAdapter extends PagerAdapter {

		// 销毁arg1位置的界面
		@Override
		public void destroyItem(View arg0, int arg1, Object arg2) {
			((ViewPager) arg0).removeView(mGuideViews.get(arg1));
		}

		// 获得当前界面数
		@Override
		public int getCount() {
			if (mGuideViews != null) {
				return mGuideViews.size();
			}

			return 0;
		}

		// 初始化arg1位置的界面
		@Override
		public Object instantiateItem(View arg0, int arg1) {

			((ViewPager) arg0).addView(mGuideViews.get(arg1), 0);

			return mGuideViews.get(arg1);
		}

		// 判断是否由对象生成界面
		@Override
		public boolean isViewFromObject(View arg0, Object arg1) {
			return (arg0 == arg1);
		}

	};

	/**
	 * 检测引导图片是否全部缓存至本地
	 * 
	 * @param paths
	 *            引导图片地址集合
	 * @return 图片全部缓存至本地返回true，其余false
	 */
	private Boolean isComplete(Object[] paths) {
		for (int i = 0; i < paths.length; i++) {
			String filePath = savePath + convertUrlToFileName(testGuidePaths[i]);
			if (null == BitmapFactory.decodeFile(filePath)) {
				return false;
			}
		}
		return true;
	}

	/**
	 * 储存图片至本地
	 * 
	 * @param path
	 *            图片地址
	 * @param isSplash
	 *            是否为启动图片 true，是；false，否
	 * 
	 */
	private void saveImage(final Object path, final Boolean isSplash) {

		// 开启子线程，缓存图片存储本地
		new Thread() {
			public void run() {
				try {

					File file = new File(savePath);
					if (!file.exists()) {
						file.mkdir();
					}

					String filePath = savePath + convertUrlToFileName(path);

					File saveFile = new File(filePath);
					if (!saveFile.exists()) {

						URL url = new URL((String) path);
						HttpURLConnection conn = (HttpURLConnection) url.openConnection();
						conn.setConnectTimeout(6 * 1000); // 注意要设置超时，设置时间不要超过10秒，避免被android系统回收

						if (conn.getResponseCode() != 200) {
							throw new RuntimeException("请求url失败");
						}

						InputStream inSream = conn.getInputStream();

						// 把图片保存到指定目录
						readAsFile(inSream, new File(filePath));

					}

					// 记录启动图片缓存位置
					if (isSplash) {
						editor.putString("filePath", filePath);
						editor.commit();
					}

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
	private String convertUrlToFileName(Object url) {
		String name = "";
		if (url != null && !"".equals(url)) {
			name = ((String) url).substring(((String) url).lastIndexOf("/") + 1, ((String) url).length());
		}
		return name;
	}

}
