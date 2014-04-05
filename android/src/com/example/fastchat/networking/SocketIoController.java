package com.example.fastchat.networking;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import com.example.fastchat.Utils;
import com.example.fastchat.fragments.MessageFragment;
import com.example.fastchat.models.Message;
import com.koushikdutta.async.http.AsyncHttpClient;
import com.koushikdutta.async.http.socketio.Acknowledge;
import com.koushikdutta.async.http.socketio.ConnectCallback;
import com.koushikdutta.async.http.socketio.EventCallback;
import com.koushikdutta.async.http.socketio.JSONCallback;
import com.koushikdutta.async.http.socketio.SocketIOClient;
import com.koushikdutta.async.http.socketio.SocketIORequest;
import com.koushikdutta.async.http.socketio.StringCallback;

public class SocketIoController {

	private static SocketIOClient client;
	
	public static void connect(){
		String newURL = NetworkManager.getURL();
		System.out.println("Socket.io connect:"+newURL+"token:"+NetworkManager.getToken());
		SocketIORequest request = new SocketIORequest(newURL,null,"token="+NetworkManager.getToken());
		//request.setHeader("token", NetworkManager.getToken());
		SocketIOClient.connect(AsyncHttpClient.getDefaultInstance(), request, new ConnectCallback() {
		    @Override
		    public void onConnectCompleted(Exception ex, SocketIOClient client) {
		        if (ex != null) {
		            ex.printStackTrace();
		            Utils.makeToast(ex);
		            return;
		        }
		        
		        client.setStringCallback(new StringCallback() {

					@Override
					public void onString(String string, Acknowledge acknowledge) {
						System.out.println("onString:"+string);
						
					}
		        });
		        client.on("message", new EventCallback() {

					@Override
					public void onEvent(JSONArray argument,
							Acknowledge acknowledge) {
						System.out.println("onEvent:"+argument);
						try {
							JSONObject messageObject = argument.getJSONObject(0);
							Message message = new Message(messageObject);
							if(message.getGroupId().equals(NetworkManager.getCurrentGroup().getId())){
								MessageFragment.addMessage(message);
							}else{
								NetworkManager.getAllGroups().get(message.getGroupId()).addMessage(message);
							}
						} catch (JSONException e) {
							// TODO Auto-generated catch block
							e.printStackTrace();
						}
						
					}
		        });
		        client.setJSONCallback(new JSONCallback() {

					@Override
					public void onJSON(JSONObject json, Acknowledge acknowledge) {
						System.out.println("onJSON:"+json);
						
					}
		        });
		        SocketIoController.client=client;
		    }
		});
	}
	
	public static void disconnect(){
		if(client!=null){
			client.disconnect();
		}
	}
	
	public static void sendMessage(Message m){
		client.emit("message",m.getSendFormat());	
	}

	public static boolean isConnected() {
		if(client==null){
			return false;
		}
		return client.isConnected();
	}
}
