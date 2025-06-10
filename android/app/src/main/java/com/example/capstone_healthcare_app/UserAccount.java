package com.example.capstone_healthcare_app;

public class UserAccount {
    private String userId;
    private String pwd;
    private String userName;

    public UserAccount() {} // Firestore에 필요한 빈 생성자

    public UserAccount(String userId, String pwd, String userName) {
        this.userId = userId;
        this.pwd = pwd;
        this.userName = userName;
    }

    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    public String getPwd() { return pwd; }
    public void setPwd(String pwd) { this.pwd = pwd; }

    public String getUserName() { return userName; }
    public void setUserName(String userName) { this.userName = userName; }
} 