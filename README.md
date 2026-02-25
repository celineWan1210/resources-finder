# Community Resource Finder (Kita Hack)

We are **Lepak Team from Monash University**. 

## Repository Overview
The **Community Resource Finder** is a Flutter application built to connect communities and facilitate the sharing of essential resources. This platform enables users to discover nearby food banks, shelters, and other vital community resources through an interactive map and user-friendly interface.

Our mission is to bridge the gap between resource surplus and local needs, fostering a resilient and supportive community ecosystem through technology.

## How to Use
To use the app, simply download it from the APK link below. You can log in if you want to contribute, or enter in **Guest Mode** to explore available contributions around Malaysia.

## App Download (APK)
You can download the latest release here: https://drive.google.com/file/d/1HT8t5y0QtjliL0eNEFP_fqYn1h6hD9lP/view?usp=sharing 

# Project Overview

### Problem Statement
In Malaysia, vulnerable groups such as low-income families, elderly people living alone and migrant workers often struggle to quickly find nearby and reliable emergency support such as food banks, shelters and community aid during a crisis. Information is scattered across outdated websites, social media posts and closed WhatsApp groups, and is often only available in English, making it difficult to know which services are still operating, whether walk-ins are allowed, or whether the information is trustworthy.<br>
At the same time, volunteers and donors share help informally online, while people in need cannot clearly signal what they need, where they are or when they need it. As a result, help may exist nearby but fails to reach those who need it most, especially outside office hours.

### SDG Alignment
The Community Resources Finder app closes the information gap, ensuring help reaches people quickly and safely.

| Goal | Target | App Alignment |
| :--- | :--- | :--- |
| **🥗 SDG 2: Zero Hunger** | **Target 2.1** | Provides real-time GPS-based discovery of verified food banks and community meal services. In 2023, Food Bank Malaysia distributed >578k kg of food ([ref](https://www.foodbanking.org/global-reach/malaysia/)), yet many still miss out due to lack of information. |
| **💰 SDG 1: No Poverty** | **Target 1.4** | Allows anonymous browsing of shelters and food banks without sign-in, removing intimidation barriers for vulnerable individuals ([ref](https://pubmed.ncbi.nlm.nih.gov/41136927/)). |
| **⚖️ SDG 10: Reduced Inequalities** | **Target 10.2** | Multilingual support and voice navigation ensure inclusion of non-English speakers, elderly, and low-literacy users who are often excluded from digital welfare ([ref](https://pmc.ncbi.nlm.nih.gov/articles/PMC10938227/)). |
| **🏙️ SDG 11: Sustainable Cities** | **Target 11.2** | Coordinates uncoordinated local resources (surplus food, spare rooms, volunteer support) via an AI-moderated map, strengthening local resilience ([ref](https://pmc.ncbi.nlm.nih.gov/articles/PMC6330151/)). |

### Solution description
Community Resources Finder is a Flutter-based mobile app that connects people in need with local support services through an interactive map. Users can search for nearby food banks, shelters, and community aid, view verified details, and get directions. The app supports multiple languages and includes voice navigation to ensure accessibility for elderly and low-literacy users. Volunteers can also post available resources, which are moderated by AI to maintain accuracy. Additionally, users can proactively ask for help through the app, which provides an instant match with available community resources. By bridging information gaps and coordinating local aid, the app strengthens community resilience and ensures help reaches those who need it most, especially outside office hours.

# Key Features 

### **1. Comprehensive Resource Discovery**
Connects users to available help within a **15km radius**:
- **Dual Resource Mapping**: displays official locations (via **Google Places API**) alongside real-time community contributions.
- **Advanced Integration**: uses the **Google Maps SDK for Android** for seamless navigation.
- **Offline Reliability**: includes localized caching to ensure data is available even with unstable connectivity.

### **2. Community-Powered Contributions**
Empowering users to share resources across multiple categories:
- **Diverse Support**: categories include *Food, Shelter, Clothes, Hygiene, Transport, Essential Supplies, and Volunteering*.
- **AI Safety (Gemini)**: integrated **Gemini AI** proactively screens all posts for scams, flagging or removing suspicious content instantly to maintain community trust.

### **3. Smart Request & Matching**
Direct, immediate assistance for those in need:
- **Instant Matching**: users can proactively broadcast a request for help, triggering a smart match against accurate community data for immediate support.
- **AI Fraud Prevention**: **Gemini AI** verifies help requests to prevent abuse and ensure resources go to genuine cases.

### **4. Human-Centered Moderation**
A dedicated **Moderator Dashboard** provides a critical layer of oversight:
- **Manual Verification**: allows trained moderators to perform human checks on flagged content, significantly reducing error and ensuring high-quality resources.

### **5. Universal Accessibility**
Designed to be used by anyone, anywhere:
- **Multilingual Support**: real-time translation for diverse communities.
- **Voice Commands**: hands-free navigation for elderly, low-literacy, or visually impaired users.