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

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.app.Activity;
import android.app.Dialog;
import android.app.ProgressDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.content.pm.PackageManager;
import android.content.pm.PackageManager.NameNotFoundException;
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

	private Display display;
	private Context context;
	private Activity activity;

	/*** 图片文件储存位置 */
	private String savePath = Environment.getExternalStorageDirectory().getPath() + "/box/";

	private Object[] testGuidePaths;

	private SharedPreferences boxPreferences;
	private Editor editor;

	private Dialog mGuideDialog; // 引导页面显示容器
	private List<View> mGuideViews; // 引导页内容list
	private ViewPager mGuidePager; // 引导页面控制控件

	private final String CONFIG_URL = "CONFIG_URL";
	private final String GUIDE_DEF_NUM = "GUIDE_DEF_NUM";

	private String mConfigUrl;
	private int mGuideDefNum;

	private final String IS_FIRST = "IS_FIRST";
	private final String LOC_VERSION = "LOC_VERSION";
	private Boolean mIsFirst;
	private int mLocVersion;

	private final String SPLASH_UPDATE = "SPLASH_UPDATE";
	private final String GUIDE_VERSION = "GUIDE_VERSION";
	private final String GUIDE_UPDATE = "GUIDE_UPDATE";
	private final String GUIDE_SHOW = "GUIDE_SHOW";
	private final String GUIDE_NUM = "GUIDE_NUM";

	private int mGuideVersion;
	private boolean mSplashUpdate;
	private Boolean mGuideUpdate;
	private Boolean mGuideShow;
	private int mGuideNum;

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
		activity = cordova.getActivity();

		try {
			mConfigUrl = activity.getPackageManager().getActivityInfo(activity.getComponentName(), PackageManager.GET_META_DATA).applicationInfo.metaData.getString(CONFIG_URL);
			mGuideDefNum = activity.getPackageManager().getActivityInfo(activity.getComponentName(), PackageManager.GET_META_DATA).applicationInfo.metaData.getInt(GUIDE_DEF_NUM);
		} catch (NameNotFoundException e) {
			e.printStackTrace();
		}

		boxPreferences = cordova.getActivity().getSharedPreferences("box_data", Context.MODE_PRIVATE);
		editor = boxPreferences.edit();

		mIsFirst = boxPreferences.getBoolean(IS_FIRST, true);
		mLocVersion = boxPreferences.getInt(LOC_VERSION, 1);

		mGuideVersion = boxPreferences.getInt(GUIDE_VERSION, 1);
		mSplashUpdate = boxPreferences.getBoolean(SPLASH_UPDATE, false);
		mGuideUpdate = boxPreferences.getBoolean(GUIDE_UPDATE, false);
		mGuideShow = boxPreferences.getBoolean(GUIDE_SHOW, false);
		mGuideNum = mIsFirst ? mGuideDefNum : boxPreferences.getInt(GUIDE_NUM, 0);

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

		getConfigInfo();

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
	@SuppressWarnings("deprecation")
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

					if ((mIsFirst || (mGuideShow && guideCompleted())) && mGuideNum > 0) {

						mGuidePager = new ViewPager(context);
						mGuideViews = new ArrayList<View>();
						@SuppressWarnings("deprecation")
						LayoutParams layoutParams = new LayoutParams(display.getWidth(), display.getHeight());
						ImageView imageView;
						String filePath;

						testGuidePaths = new Object[mGuideNum];

						for (int i = 0; i < testGuidePaths.length; i++) {

							imageView = new ImageView(context);

							if (mIsFirst) {
								testGuidePaths[i] = cordova.getActivity().getResources().getIdentifier("guide_" + (i + 1), "drawable", cordova.getActivity().getClass().getPackage().getName());
								imageView.setImageResource((Integer) testGuidePaths[i]);
							} else {
								testGuidePaths[i] = "guide_" + (i + 1) + ".png";
								filePath = savePath + testGuidePaths[i];
								imageView.setImageBitmap(BitmapFactory.decodeFile(filePath));
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

										if (mIsFirst) {
											editor.putBoolean(IS_FIRST, false);
										} else {
											editor.putInt(LOC_VERSION, mGuideVersion);
											editor.putBoolean(GUIDE_SHOW, false);
										}
										editor.commit();

									}
								});
							}
							mGuideViews.add(imageView);

						}

						mGuidePager.setAdapter(new guideAdapter());

						mGuideDialog = new Dialog(context, android.R.style.Theme_Translucent_NoTitleBar);

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

				if (splashCompleted()) {
					splashImageView.setImageBitmap(BitmapFactory.decodeFile(savePath + "splash.png"));
				} else {
					splashImageView.setImageResource(drawableId);
				}

				LayoutParams layoutParams = new LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT);
				splashImageView.setLayoutParams(layoutParams);

				splashImageView.setMinimumHeight(display.getHeight());
				splashImageView.setMinimumWidth(display.getWidth());

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
	 * 储存图片至本地
	 * 
	 * @param path
	 *            图片地址
	 * @param isSplash
	 *            是否为启动图片 true，是；false，否
	 * 
	 */
	private void saveImage(final String path) {

		// 开启子线程，缓存图片存储本地
		new Thread() {
			public void run() {
				try {

					File file = new File(savePath);
					if (!file.exists()) {
						file.mkdir();
					}

					URL url = new URL(path);
					HttpURLConnection conn = (HttpURLConnection) url.openConnection();
					conn.setConnectTimeout(6 * 1000); // 注意要设置超时，设置时间不要超过10秒，避免被android系统回收

					if (conn.getResponseCode() != 200) {
						throw new RuntimeException("请求url失败");
					}

					InputStream inSream = conn.getInputStream();

					FileOutputStream outStream = new FileOutputStream(new File(savePath + convertUrlToFileName(path)));
					byte[] buffer = new byte[1024];
					int len = -1;
					while ((len = inSream.read(buffer)) != -1) {
						outStream.write(buffer, 0, len);
					}
					outStream.close();
					inSream.close();

				} catch (Exception e) {
					e.printStackTrace();
				}
			};
		}.start();
	}

	/**
	 * 从图片路径中获取图片名
	 * 
	 * @param url
	 */
	private String convertUrlToFileName(String url) {
		String name = "";
		if (url != null && !"".equals(url)) {
			name = ((String) url).substring((url).lastIndexOf("/") + 1, ((String) url).length());
		}
		return name;
	}

	/**
	 * 获取配置文件内信息，获取是否需要更新启动页、是否需要更新引导页、是否展现新引导页、引导页数量
	 */
	private void getConfigInfo() {

		new Thread() {
			public void run() {
				try {

					URL url = new URL(mConfigUrl + "guide_config.txt");
					HttpURLConnection conn = (HttpURLConnection) url.openConnection();
					conn.setConnectTimeout(6 * 1000); // 注意要设置超时，设置时间不要超过10秒，避免被android系统回收

					if (conn.getResponseCode() != 200) {
						throw new RuntimeException("请求url失败");
					} else {

						InputStream inSream = conn.getInputStream();

						InputStreamReader inputStreamReader = null;
						inputStreamReader = new InputStreamReader(inSream);
						BufferedReader reader = new BufferedReader(inputStreamReader);
						StringBuffer sb = new StringBuffer("");
						String line;
						while ((line = reader.readLine()) != null) {
							sb.append(line);
							sb.append("\n");
						}
						String json = sb.toString();

						JSONObject jsonObject = new JSONObject(json);

						editor.putInt(GUIDE_VERSION, jsonObject.getInt("guideVersion"));
						editor.putBoolean(SPLASH_UPDATE, jsonObject.getBoolean("splashUpdate"));
						editor.putBoolean(GUIDE_UPDATE, jsonObject.getBoolean("guideUpdate"));
						if (mLocVersion != mGuideVersion) {
							editor.putBoolean(GUIDE_SHOW, jsonObject.getBoolean("guideShow"));
						}
						editor.putInt(GUIDE_NUM, jsonObject.getInt("guideNum"));
						editor.commit();

						saveSplashImage();
						saveGuideImagse();

					}
				} catch (Exception e) {
					e.printStackTrace();
				}
			};
		}.start();

	}

	/**
	 * 储存启动页至本地
	 */
	private void saveSplashImage() {

		if (mSplashUpdate) {
			saveImage(mConfigUrl + "splash/splash.png");
		}

	}

	/**
	 * 检查新启动页是否缓存至本地
	 * 
	 * @return true 已缓存
	 */
	private Boolean splashCompleted() {

		File file = new File(savePath + "splash.png");
		if (!file.exists()) {
			return false;
		}

		return true;
	}

	/**
	 * 储存引导页至本地
	 */
	private void saveGuideImagse() {

		if (mGuideUpdate && (mLocVersion != mGuideVersion)) {
			for (int i = 0; i < mGuideDefNum; i++) {
				saveImage(mConfigUrl + "guides/guide_" + (i + 1) + ".png");
			}
		}
	}

	/**
	 * 检查新引导页是否缓存至本地
	 * 
	 * @return true 已缓存
	 */
	private Boolean guideCompleted() {
		Boolean completed = true;
		for (int i = 0; i < mGuideDefNum; i++) {
			File file = new File(savePath + "guide_" + (i + 1) + ".png");
			if (!file.exists()) {
				completed = false;
			}
		}
		return completed;
	}

}
